require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get grader_configuration_index_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected" do
    sign_in_as("john", "hello")
    get grader_configuration_index_path
    assert_redirected_to list_main_path
  end

  test "group editor is redirected" do
    sign_in_as("mary", "mary")
    get grader_configuration_index_path
    assert_redirected_to list_main_path
  end

  # --- Index/edit/update/toggle ---

  test "admin can access index and sees reorganized system parameters and gimmicks" do
    sign_in_as("admin", "admin")
    get grader_configuration_index_path
    assert_response :success
    assert_select ".card[data-group='gimmicks']" do
      assert_select ".config-item[data-key='gimmicks.theme_selector_enabled'] .gimmick-state-group"
    end
    assert_select ".config-item[data-key='system.scoreboard_enabled'] .gimmick-state-group"
    assert_select ".config-item[data-key='right.user_hall_of_fame'] .gimmick-state-group"
    assert_select ".card[data-group='system']" do
      assert_select ".config-subgroup-header", minimum: 4
      assert_select ".config-subgroup-header", text: /Mode & Access Control/
      assert_select ".config-subgroup-header", text: /Scoreboard & Scoring/
      assert_select ".config-subgroup-header", text: /Student Features & Assistance/
      assert_select ".config-subgroup-header", text: /Registration & Administration/
    end
  end

  test "admin can update configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "ui.front.title")
    patch grader_configuration_path(config), params: {
      grader_configuration: { value: "New Title" }
    }
    assert_equal "New Title", config.reload.value
  end

  test "admin can toggle boolean configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "system.single_user_mode")
    patch toggle_grader_configuration_path(config)
    assert_equal "true", config.reload.value
  end

  test "admin can edit configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "ui.front.title")
    get edit_grader_configuration_path(config)
    assert_response :success
  end

  # --- Collection actions ---

  test "admin can reload config cache" do
    sign_in_as("admin", "admin")
    get reload_grader_configuration_index_path
    assert_response :redirect
  end

  test "admin can clear all user IPs" do
    sign_in_as("admin", "admin")
    # Set a user's last_ip so we can verify the clear effect
    users(:john).update_column(:last_ip, "deadbeef")
    post clear_user_ip_grader_configuration_index_path, as: :turbo_stream
    assert_response :success
    assert_nil users(:john).reload.last_ip
  end

  test "admin can update 3-state gimmick, scoreboard, and hall of fame configs" do
    sign_in_as("admin", "admin")
    %w[gimmicks.enable_bonus system.scoreboard_enabled right.user_hall_of_fame].each do |key|
      config = GraderConfiguration.find_by!(key: key)
      patch grader_configuration_path(config), params: {
        grader_configuration: { value: "outside_contest" }
      }, as: :turbo_stream
      assert_response :success
      assert_equal "outside_contest", config.reload.value
    end
  end

  test "admin can set exam right which cascades to system mode" do
    sign_in_as("admin", "admin")
    get set_exam_right_grader_configuration_index_path(value: "true")
    assert_response :redirect # redirects to index
  end
end
