-- Runs after payment_reconciliation_v1_fixtures.sql in the same transaction/session.
set local role anon;
select pg_temp.bank_error('anon preview denied','select public.admin_preview_payment_reconciliation(gen_random_uuid())','42501');
select pg_temp.bank_error('anon mutation denied','select public.admin_reconcile_bank_transaction(null,null,1,1,1,''test reason'',gen_random_uuid())','42501');
reset role;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.bank_error('customer denied','select public.admin_list_reconciliation_exceptions()','42501');
reset role;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.bank_error('rescuer denied','select public.admin_list_reconciliation_exceptions()','42501');
reset role;
select set_config('request.jwt.claim.sub','a1700000-0000-4000-8000-000000000003',true);
set local role authenticated;
select pg_temp.bank_error('finance without payment.reconcile denied','select public.admin_list_reconciliation_exceptions()','42501');
select pg_temp.bank_error('restricted mutation denied','select pg_temp.rec_call(1)','42501');
select pg_temp.bank_error('cannot self grant','select public.admin_set_payment_reconcile_permission(auth.uid(),true,0,''self grant forbidden'')','42501');
select pg_temp.bank_error('no direct paid writer','update public.payments set status=''paid''','42501');
select pg_temp.bank_error('no direct allocation','insert into private.payment_reconciliation_settlements(id) values(gen_random_uuid())','42501');
reset role;
select set_config('request.jwt.claim.sub','a1700000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.bank_assert('explicit operator allowed',(public.admin_list_reconciliation_exceptions()->>'pending_count')::integer>=16);
select pg_temp.bank_assert('candidate exact evidence visible',(
 select (public.admin_preview_payment_reconciliation(transaction_id)->'candidates'->0->>'eligible')::boolean from private.reconciliation_test_cases where i=1));
select pg_temp.bank_error('amount mismatch blocked','select pg_temp.rec_call(3)','23514');
select pg_temp.bank_error('beneficiary mismatch blocked','select pg_temp.rec_call(4)','23514');
select pg_temp.bank_error('after expiry blocked','select pg_temp.rec_call(5)','23514');
select pg_temp.bank_error('amount/time alone insufficient','select pg_temp.rec_call(6)','23514');
select pg_temp.bank_error('ambiguous references blocked','select pg_temp.rec_call(7)','23514');
select pg_temp.bank_error('before intent blocked','select pg_temp.rec_call(8)','23514');
select pg_temp.bank_error('stale payment version','select public.admin_reconcile_bank_transaction(transaction_id,payment_id,transaction_version,payment_version+1,intent_version,''valid mandatory reason'',gen_random_uuid()) from private.reconciliation_test_cases where i=1','40001');
select pg_temp.bank_error('stale transaction version','select public.admin_reconcile_bank_transaction(transaction_id,payment_id,transaction_version+1,payment_version,intent_version,''valid mandatory reason'',gen_random_uuid()) from private.reconciliation_test_cases where i=1','40001');
select pg_temp.bank_error('stale intent version','select public.admin_reconcile_bank_transaction(transaction_id,payment_id,transaction_version,payment_version,intent_version+1,''valid mandatory reason'',gen_random_uuid()) from private.reconciliation_test_cases where i=1','40001');
select pg_temp.bank_error('reason required','select public.admin_reconcile_bank_transaction(transaction_id,payment_id,transaction_version,payment_version,intent_version,'' '',gen_random_uuid()) from private.reconciliation_test_cases where i=1','22023');
select pg_temp.bank_assert('reference recovery succeeds',(pg_temp.rec_call(1,'b1700000-0000-4000-8000-000000000001')->>'changed')::boolean);
select pg_temp.bank_assert('operation replay no financial effect',not (pg_temp.rec_call(1,'b1700000-0000-4000-8000-000000000001')->>'changed')::boolean);
select pg_temp.bank_error('operation reuse conflict','select pg_temp.rec_call(2,''b1700000-0000-4000-8000-000000000001'')','22023');
select pg_temp.bank_error('new operation cannot settle same transaction','select pg_temp.rec_call(1)','40001');
select pg_temp.bank_assert('occurred before expiry with delayed webhook succeeds',(pg_temp.rec_call(2)->>'changed')::boolean);
reset role;
select pg_temp.bank_assert('one paid event per payment',not exists(select 1 from public.payment_events where event_type='bank_payment_verified' group by payment_id having count(*)<>1));
select pg_temp.bank_assert('two allocations and two paid events',(select count(*)=2 from private.payment_reconciliation_settlements)
  and (select count(*)=2 from public.payment_events where event_type='bank_payment_verified'));
select pg_temp.bank_assert('immutable exact audit includes actor reason states versions and evidence',not exists(
 select 1 from private.payment_reconciliation_settlements where actor_id<>'a1700000-0000-4000-8000-000000000002'
 or length(reason)<10 or occurred_at>processed_at or old_states->>'payment'<>'awaiting_payment' or new_states->>'payment'<>'paid'
 or evidence->>'beneficiary_exact'<>'true' or evidence->>'reference_bound'<>'true' or payment_version<>2));
select pg_temp.bank_assert('receipt history preserved',exists(select 1 from private.reconciliation_test_cases c
 join private.bank_transactions t on t.id=c.transaction_id join private.payment_webhook_receipts w on w.id=t.receipt_id
 where c.i=1 and w.result_code='reference_unmatched' and w.status='processed'));
select pg_temp.bank_assert('webhook replay no settlement',(private.process_verified_bank_transaction((select observation from private.reconciliation_test_cases where i=1))->>'changed')::boolean=false);
select pg_temp.bank_error('audit update forbidden','update private.payment_reconciliation_settlements set reason=''different reason''','23514');
select pg_temp.bank_error('audit truncate forbidden','truncate private.payment_reconciliation_settlements','23514');
select pg_temp.bank_error('permission audit immutable','delete from private.payment_reconcile_permission_audit','23514');
select pg_temp.bank_assert('no secrets in DTO',(
  select public.admin_preview_payment_reconciliation(transaction_id)::text !~ 'body_sha256|account_number|raw_body|normalized_sha256' from private.reconciliation_test_cases where i=1));
select set_config('request.jwt.claim.sub','a1700000-0000-4000-8000-000000000001',true);
select pg_temp.bank_assert('super admin allowed',(public.admin_list_reconciliation_exceptions()->>'pending_count')::integer>0);
select public.admin_set_payment_reconcile_permission('a1700000-0000-4000-8000-000000000002',false,1,'Revoke synthetic permission');
select pg_temp.bank_error('grant stale guard','select public.admin_set_payment_reconcile_permission(''a1700000-0000-4000-8000-000000000002'',true,1,''stale synthetic permission'')','40001');
select set_config('request.jwt.claim.sub','a1700000-0000-4000-8000-000000000002',true);
select pg_temp.bank_error('revoked operator denied','select public.admin_list_reconciliation_exceptions()','42501');
select pg_temp.bank_assert('all new public functions fixed path',not exists(select 1 from pg_proc where proname in
 ('admin_set_payment_reconcile_permission','admin_list_reconciliation_exceptions','admin_preview_payment_reconciliation','admin_reconcile_bank_transaction')
 and proconfig is distinct from array['search_path=""']));
select pg_temp.bank_assert('no private API grants',not has_table_privilege('authenticated','private.payment_reconciliation_settlements','SELECT,INSERT,UPDATE,DELETE')
 and not has_function_privilege('service_role','public.admin_reconcile_bank_transaction(uuid,uuid,bigint,bigint,bigint,text,uuid)','EXECUTE'));
select 'PAYMENT_RECONCILIATION_V1_PASS' result,count(*) assertions from bank_results;
rollback;
