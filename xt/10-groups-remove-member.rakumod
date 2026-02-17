use Test;

use lib 'xt/lib';
use TestRender;
use TestUtil;
use Zeco::DB;
use Zeco::Query::Users;
use Zeco::Query::Groups;
use Zeco::Util::Types;
use Zeco::Util::Json;
use Zeco::Responses;

plan 30;

cleanup('xyz@abc.com');

my $test-render = TestRender.new;
my $user-q = QRegister.new(:email(email), :username<tonyo-test>, :password<password>);

# sign up
register(QRegister.new(:email('xyz@abc.com'), :username<abc>, :password<password>)).render($test-render);
$test-render.assert(200, {:success});

register($user-q).render($test-render);
$test-render.assert(200, {:success});

ok !group-exists('tonyo-group-test').so,
   "group 'tonyo-group-test' exists";
ok !is-group-admin('tonyo-group-test', user-id).so,
   'user is admin of group by default';

$user-q = QCreateGroup.new(:email(grup), :group<tonyo-group-test>);
create-group($user-q, user-id).render($test-render);
$test-render.assert(200, {:success});

my $admin-id = db.query("SELECT user_id FROM users WHERE username = 'tonyo-test'").hashes[0]<user_id>;
ok $admin-id > 0;
my $user-id = db.query("SELECT user_id FROM users WHERE username = 'abc'").hashes[0]<user_id>;
ok $user-id > 0;

# error for a group i'm not admin of 
delete-member-from-group(QGroupUser.new(group => 'not-an-admin', user => 'abc'), $admin-id).render($test-render); 
$test-render.assert(403, {:!success, :message('You must be an admin to perform this action.')});


delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'tonyo-test'), $user-id).render($test-render); 
$test-render.assert(403, {:!success, :message('You must be an admin to perform this action.')});

# user is not a member of group
delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'abc'), $admin-id).render($test-render); 
$test-render.assert(404, {:!success, :message('Not found.')});

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'abc2'), $admin-id).render($test-render); 
$test-render.assert(404, {:!success, :message('Not found.')});

# add abc as an admin
invite-groups(QGroupUserRole.new(group => 'tonyo-group-test', user => 'abc', role => 'admin'), $admin-id);
accept-invite-groups(QGroup.new(group => 'tonyo-group-test'), $user-id); 

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'abc'), $admin-id).render($test-render); 
$test-render.assert(200, {:success});

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'tonyo-test'), $user-id).render($test-render); 
$test-render.assert(403, {:!success, :message('You must be an admin to perform this action.')});

# make sure a user cannot remove other users
invite-groups(QGroupUserRole.new(group => 'tonyo-group-test', user => 'abc', role => 'member'), $admin-id);
accept-invite-groups(QGroup.new(group => 'tonyo-group-test'), $user-id); 

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'tonyo-test'), $user-id).render($test-render); 
$test-render.assert(403, {:!success, :message('You must be an admin to perform this action.')});

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'abc'), $admin-id).render($test-render); 
$test-render.assert(200, {:success});

# make sure a non-creating admin can remove another admin
invite-groups(QGroupUserRole.new(group => 'tonyo-group-test', user => 'abc', role => 'admin'), $admin-id);
accept-invite-groups(QGroup.new(group => 'tonyo-group-test'), $user-id); 

delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'tonyo-test'), $user-id).render($test-render); 
$test-render.assert(200, {:success});

# finally, make sure this endpoint cannot be used to remove themselves (prevent accidental orphan groups)
delete-member-from-group(QGroupUser.new(group => 'tonyo-group-test', user => 'abc'), $user-id).render($test-render); 
$test-render.assert(404, {:!success, :message('Not found.')});
