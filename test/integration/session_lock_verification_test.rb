require "test_helper"

class SessionLockVerificationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @john = users(:john)
    @james = users(:james)
    @contest = contests(:contest_a)
  end

  test "1. ConfigurationsController#clear_user_ip clears all user locks" do
    sign_in_as(@admin.login, "admin")
    @john.update_column(:last_ip, "john-uuid")
    @james.update_column(:last_ip, "james-uuid")

    post clear_user_ip_grader_configuration_index_path, as: :turbo_stream
    assert_response :success
    assert_nil @john.reload.last_ip
    assert_nil @james.reload.last_ip
  end

  test "2. ContestsController#do_all_users with clear_ip clears locks for contest users" do
    sign_in_as(@admin.login, "admin")
    @james.update_column(:last_ip, "james-uuid")
    assert @contest.users.include?(@james)

    post do_all_users_contest_path(@contest), params: { command: "clear_ip" }, as: :turbo_stream
    assert_response :success
    assert_nil @james.reload.last_ip
  end

  test "3. ContestsController#do_user with clear_ip clears lock for a single contest user" do
    sign_in_as(@admin.login, "admin")
    @james.update_column(:last_ip, "james-uuid")

    post do_user_contest_path(@contest), params: { user_id: @james.id, command: "clear_ip" }, as: :turbo_stream
    assert_response :success
    assert_nil @james.reload.last_ip
  end

  test "4. UserAdminController#user_action with clear_ip clears lock for single user via AJAX" do
    sign_in_as(@admin.login, "admin")
    @john.update_column(:last_ip, "john-uuid")

    post user_action_user_admin_index_path, params: { user_id: @john.id, command: "clear_ip" }, as: :turbo_stream
    assert_response :success
    assert_nil @john.reload.last_ip
  end

  test "5. UserAdminController#clear_last_ip clears lock for single user via GET fallback" do
    sign_in_as(@admin.login, "admin")
    @john.update_column(:last_ip, "john-uuid")

    get clear_last_ip_user_admin_path(@john)
    assert_redirected_to user_admin_index_path
    assert_nil @john.reload.last_ip
  end

  test "6. Detection of login from more than 1 place (session locking)" do
    set_grader_config("right.multiple_ip_login", "false")
    set_grader_config("right.bypass_agreement", "true")

    # Device 1 logs in
    device1 = open_session
    device1.post login_login_path, params: { login: @john.login, password: "hello" }
    assert_equal 302, device1.response.status

    # Device 1 accesses the system and establishes its lock
    device1.get list_main_path
    assert_equal 200, device1.response.status
    locked_uuid = @john.reload.last_ip
    assert_not_nil locked_uuid

    # Device 2 logs in with the same account
    device2 = open_session
    device2.post login_login_path, params: { login: @john.login, password: "hello" }
    assert_equal 302, device2.response.status

    # Manually change john's locked last_ip (simulating another machine having taken the lock)
    @john.update_columns(last_ip: "different-device-uuid")

    # Now when device1 makes a request, it detects the mismatch
    device1.get list_main_path
    assert_equal 302, device1.response.status
    assert_equal "You cannot login from two different places", device1.flash[:alert]
  end
end
