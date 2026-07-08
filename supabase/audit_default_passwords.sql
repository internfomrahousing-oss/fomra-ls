-- Audit: which accounts are STILL on the built-in default password?
--
-- An account is "on the default" when it has no row in account_passwords
-- (i.e. nobody has ever changed it). Run this in the Supabase SQL editor.
--
-- Every employee/portal email that appears here should be forced to change
-- their password. Until the app wires a forced-change screen (using
-- account_uses_default_password()), notify these users to change it manually
-- via Settings → Change Password.

select e.email,
       account_uses_default_password(e.email) as on_default_password
from employee_profiles e
order by on_default_password desc, e.email;

-- Portal accounts (not in employee_profiles):
select 'management@fomrahousing.in' as account,
       account_uses_default_password('management@fomrahousing.in') as on_default_password
union all
select 'employee@fomrahousing.in',
       account_uses_default_password('employee@fomrahousing.in');
