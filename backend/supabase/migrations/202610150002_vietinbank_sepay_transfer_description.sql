-- VietinBank + SePay Live: distinguish the bank memo from the canonical match key.
-- New snapshots only. No config seed/change, historical snapshot rewrite, or
-- changes to private.process_verified_bank_transaction / settlement protections.
-- SEVQR + space + BK[0-9]{19} = 27 ASCII bytes. This is a narrow local encoder
-- extension, not a generic memo-length increase. TLV values remain <=99 bytes,
-- nested 62/08 is 31/27 bytes, and the full QR remains <=512 bytes with CRC16.
-- External 25-character QR APIs must NOT be used to truncate this description.
-- Bank-app scan compatibility is a deployment acceptance gate; see runbook.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $preflight$
begin
  if to_regprocedure('public.customer_regenerate_bank_transfer(uuid,uuid,bigint,uuid,bigint,uuid)') is null
     or to_regprocedure('private.system_require_session()') is null
     or to_regprocedure('private.process_verified_bank_transaction(jsonb)') is null
     or to_regprocedure('private.payment_bank_vietqr(text,text,bigint,text)') is null then
    raise exception 'BANK_SEVQR_MISSING_PREREQUISITES';
  end if;
end;
$preflight$;

create or replace function private.payment_bank_vietqr(p_bin text,p_account text,p_amount bigint,p_content text)
returns text language plpgsql immutable security invoker set search_path='' as $$
declare v_payload text;
begin
  if p_bin is null or p_bin !~ '^[0-9]{6}$' or p_account is null or p_account !~ '^[0-9]{6,19}$'
     or p_amount is null or p_amount not between 1 and 9999999999999
     or p_content is null or not (p_content ~ '^[A-Z0-9]{1,25}$'
       or (p_bin='970415' and octet_length(p_content)=27 and p_content ~ '^SEVQR BK[0-9]{19}$')) then
    raise exception 'BANK_QR_VALUE_INVALID' using errcode='22023';
  end if;
  v_payload:='000201010212'||private.payment_bank_tlv('38',
    private.payment_bank_tlv('00','A000000727')||private.payment_bank_tlv('01',
      private.payment_bank_tlv('00',p_bin)||private.payment_bank_tlv('01',p_account))||
    private.payment_bank_tlv('02','QRIBFTTA'))||'5303704'||private.payment_bank_tlv('54',p_amount::text)||
    '5802VN'||private.payment_bank_tlv('62',private.payment_bank_tlv('08',p_content))||'6304';
  if octet_length(v_payload)+4 > 512 then
    raise exception 'BANK_QR_VALUE_INVALID' using errcode='22023';
  end if;
  return v_payload||private.payment_bank_crc16(v_payload);
end;
$$;

create or replace function private.payment_bank_qr_snapshot_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
declare c private.payment_bank_config; i private.payment_bank_intents;
begin
  if tg_op<>'INSERT' then raise exception 'BANK_QR_SNAPSHOT_IMMUTABLE' using errcode='23514'; end if;
  select * into c from private.payment_bank_config where singleton and enabled for share;
  if not found then raise exception 'BANK_UNAVAILABLE' using errcode='P0001'; end if;
  select * into i from private.payment_bank_intents where id=new.intent_id for update;
  if not found or i.status<>'created' or i.expires_at<=pg_catalog.clock_timestamp()
     or not exists(select 1 from public.payments p where p.id=i.payment_id
       and p.customer_id=auth.uid() and ((p.method is null and p.status='pending')
         or (p.method='bank_transfer' and p.status='awaiting_payment'))) then
    raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001';
  end if;
  new.config_version:=c.version;
  new.bank_bin:=c.bank_bin; new.bank_code:=c.bank_code; new.bank_name:=c.bank_name;
  new.account_number:=c.account_number; new.account_name:=c.account_name;
  new.transfer_content:='BK'||pg_catalog.lpad(
    pg_catalog.nextval('private.payment_bank_transfer_seq'::regclass)::text,19,'0');
  new.qr_payload:=private.payment_bank_vietqr(
    c.bank_bin,c.account_number,i.expected_amount,
    case when c.bank_bin='970415' and c.verification_provider='sepay'
      and c.verification_scope is not null and c.verification_scope<>'sepay_test'
      then 'SEVQR '||new.transfer_content else new.transfer_content end);
  return new;
end;
$$;

create or replace function public.customer_get_bank_payment(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); p public.payments; i private.payment_bank_intents;
  s private.payment_bank_qr_snapshots; v_status text; v_enabled boolean;
begin
  if auth.uid() is not null then perform private.system_require_session(); end if;
  if v_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from public.rescue_requests r where r.id=p_request_id and r.customer_id=v_actor) then
    raise exception 'PAYMENT_NOT_ACCESSIBLE' using errcode='42501';
  end if;
  select * into p from public.payments where request_id=p_request_id and customer_id=v_actor;
  if not found or p.method is distinct from 'bank_transfer' then return null; end if;
  select b.* into i from private.payment_bank_intents b
    join private.payment_bank_qr_snapshots q on q.intent_id=b.id
    where b.payment_id=p.id order by b.created_at desc,b.id limit 1;
  if not found then raise exception 'BANK_INTENT_UNAVAILABLE' using errcode='P0001'; end if;
  select * into s from private.payment_bank_qr_snapshots where intent_id=i.id;
  select exists(select 1 from private.payment_bank_config c where c.singleton and c.enabled) into v_enabled;
  v_status:=case when i.status in ('created','ready') and i.expires_at<=pg_catalog.statement_timestamp()
    then 'expired' else i.status end;
  return pg_catalog.jsonb_build_object(
    'payment_id',p.id,'payment_code',p.payment_code,'request_id',p.request_id,
    'payment_status',p.status,'payment_method',p.method,'amount_expected',p.amount_expected::text,'currency',p.currency,
    'bank_intent_id',i.id,'bank_intent_status',v_status,'bank_reference',i.reference,
    'bank_code',s.bank_code,'bank_bin',s.bank_bin,'bank_name',s.bank_name,
    'account_number',s.account_number,'account_name',s.account_name,'transfer_content',s.transfer_content,
    'transfer_description',case when s.bank_bin='970415' then
      case when s.qr_payload=private.payment_bank_vietqr(
        s.bank_bin,s.account_number,i.expected_amount,'SEVQR '||s.transfer_content)
        then 'SEVQR '||s.transfer_content else s.transfer_content end
      else s.transfer_content end,
    'expires_at',i.expires_at,'server_time',pg_catalog.statement_timestamp(),
    'available',v_enabled,'qr_payload',case when v_enabled and v_status='ready' and p.status='awaiting_payment' then s.qr_payload end,
    'version',p.version::text,'bank_intent_version',i.version::text);
end;
$$;

-- CREATE OR REPLACE preserves existing ownership, security mode and ACLs.
-- In particular, no client is granted access to private QR helpers/config.
commit;
