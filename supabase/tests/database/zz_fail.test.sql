begin;
select plan(1);
select ok(false, 'deliberate CI failure');
select * from finish();
rollback;
