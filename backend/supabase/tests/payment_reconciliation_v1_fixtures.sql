-- Appended to the existing bank verification fixture prelude by regression runners.
-- Never run on production. All data and provider observations are synthetic.
do $$ begin
  if current_setting('payment.test_mode',true) is distinct from 'local_disposable' then raise exception 'LOCAL_TEST_ONLY'; end if;
end $$;
insert into auth.users(id,email) select ('a1700000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  'reconciliation-'||n||'@example.invalid' from generate_series(1,5) n;
insert into public.admin_profiles(id,full_name,role,status) values
 ('a1700000-0000-4000-8000-000000000001','Reconcile Super','super_admin','active'),
 ('a1700000-0000-4000-8000-000000000002','Reconcile Operator','operator','active'),
 ('a1700000-0000-4000-8000-000000000003','Restricted Finance','finance','active'),
 ('a1700000-0000-4000-8000-000000000004','Reconcile Operator Two','operator','active'),
 ('a1700000-0000-4000-8000-000000000005','Reconcile Support','support','active');
select set_config('request.jwt.claim.sub','a1700000-0000-4000-8000-000000000001',true);
select public.admin_set_payment_reconcile_permission('a1700000-0000-4000-8000-000000000002',true,0,'Synthetic operator permission');
select public.admin_set_payment_reconcile_permission('a1700000-0000-4000-8000-000000000004',true,0,'Synthetic second operator permission');
select set_config('request.jwt.claim.sub','',true);
update private.payment_bank_config set verification_provider='sepay',verification_scope='sepay_live';
update bank_inputs set n=n||jsonb_build_object('provider','sepay','provider_scope','sepay_live','authentication_method','signature','signature_verified',true);
-- Time travel only in this privileged disposable fixture; not a production path.
alter table private.payment_bank_intents disable trigger bank_intent_guard;
update private.payment_bank_intents i set created_at=clock_timestamp()-interval '5 minutes',updated_at=clock_timestamp()
  from bank_fixtures f where f.payment_id=i.payment_id;
update private.payment_bank_intents i set created_at=clock_timestamp()-interval '2 hours',
  expires_at=clock_timestamp()-interval '1 hour',updated_at=clock_timestamp()
  from bank_fixtures f where f.payment_id=i.payment_id and f.i in (2,5);
alter table private.payment_bank_intents enable trigger bank_intent_guard;
update bank_inputs set n=n||jsonb_build_object('occurred_at',to_char((clock_timestamp()-interval '1 minute') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
update bank_inputs set n=n||jsonb_build_object('occurred_at',to_char((clock_timestamp()-interval '90 minutes') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) where i=2;
update bank_inputs set n=n||jsonb_build_object('transfer_reference','SEVQR '||(n->>'transfer_reference')) where i not in (2,3,4,5);
update bank_inputs set n=n||'{"amount":"1"}' where i=3;
update bank_inputs set n=n||'{"beneficiary_account_number":"999999999999"}' where i=4;
update bank_inputs set n=n||'{"transfer_reference":"unrelated transfer"}' where i=6;
update bank_inputs set n=n||jsonb_build_object('transfer_reference',(n->>'transfer_reference')||' '||(select b.n->>'transfer_reference' from bank_inputs b where b.i=1)) where i=7;
update bank_inputs set n=n||jsonb_build_object('occurred_at','2000-01-01T00:00:00Z') where i=8;
select private.process_verified_bank_transaction(n) from bank_inputs where i between 1 and 16;
-- A second bank transaction pointing at the same payment, for real races.
select private.process_verified_bank_transaction(n||'{"provider_transaction_id":"tx-10-second","provider_event_id":"event-10-second","delivery_id":"delivery-10-second"}') from bank_inputs where i=10;
create table private.reconciliation_test_cases as
select f.i,p.id payment_id,t.id transaction_id,t.version transaction_version,p.version payment_version,
  i.version intent_version,i.id intent_id,n.n observation,gen_random_uuid() operation_id
from bank_fixtures f join public.payments p on p.id=f.payment_id
join private.payment_bank_intents i on i.payment_id=p.id
join bank_inputs n on n.i=f.i
join private.bank_transactions t on t.external_transaction_id='tx-'||f.i;
create function pg_temp.rec_call(p_i integer,p_operation uuid default gen_random_uuid()) returns jsonb
language sql security invoker as $$
 select public.admin_reconcile_bank_transaction(transaction_id,payment_id,transaction_version,payment_version,
   intent_version,'Verified synthetic transfer evidence',p_operation) from private.reconciliation_test_cases where i=p_i;
$$;
-- Test-only grants on synthetic fixture lookup, never on financial data.
grant usage on schema private to authenticated;
grant select on private.reconciliation_test_cases to authenticated;
