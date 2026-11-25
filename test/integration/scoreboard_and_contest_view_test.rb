require "test_helper"

class ScoreboardAndContestViewTest < ActionDispatch::IntegrationTest
  setup do
    GraderConfiguration.find_or_create_by!(key: "system.scoreboard_enabled") do |c|
      c.value_type = "string"
      c.value = "always_on"
    end.update!(value_type: "string", value: "always_on")
    GraderConfiguration.find_or_create_by!(key: "system.scoreboard_view_level") do |c|
      c.value_type = "string"
      c.value = "all"
    end.update!(value: "all")
    GraderConfiguration.find_or_create_by!(key: "gimmicks.theme_selector_enabled") do |c|
      c.value_type = "string"
      c.value = "always_on"
    end.update!(value_type: "string", value: "always_on")
    reset_grader_config_cache
  end

  test "scoreboard renders modern virtualized structure in individual and group modes" do
    sign_in_as("admin", "admin")

    get scoreboard_path
    assert_response :success
    assert_select ".scoreboard-card"
    assert_select ".scoreboard-scroll-wrapper"
    assert_select "#scoreboard-search"
    assert_select "script#scoreboard-data"

    get scoreboard_path(format: :json)
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "individual", payload["mode"]
    assert payload["problems"].is_a?(Array)
    assert payload["rows"].is_a?(Array)

    get scoreboard_path(mode: "group")
    assert_response :success
    assert_select ".scoreboard-card"
    assert_select "script#scoreboard-data"
  end

  test "scoreboard in contest mode shows only users and problems from enabled contests" do
    sign_in_as("admin", "admin")
    set_grader_config("system.mode", "contest")
    set_grader_config("system.scoreboard_enabled", "always_on")

    # Ensure only one contest is enabled and another is disabled
    Contest.update_all(enabled: false)
    enabled_contest = Contest.create!(name: "sb_enabled_contest", enabled: true, start: 1.hour.ago, stop: 2.hours.from_now)
    disabled_contest = Contest.create!(name: "sb_disabled_contest", enabled: false, start: 1.hour.ago, stop: 2.hours.from_now)

    u_in = users(:john)
    u_out = users(:mary)
    p_in = problems(:prob_add)
    p_out = problems(:hard)
    p_in.update!(available: true)
    p_out.update!(available: true)

    ContestUser.create!(contest: enabled_contest, user: u_in, enabled: true)
    ContestUser.create!(contest: disabled_contest, user: u_out, enabled: true)
    ContestProblem.create!(contest: enabled_contest, problem: p_in, enabled: true, number: 1)
    ContestProblem.create!(contest: disabled_contest, problem: p_out, enabled: true, number: 1)

    get scoreboard_path(format: :json)
    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal true, payload["contest_mode"]
    assert_equal [p_in.id], payload["problems"].map { |p| p["id"] }
    assert_equal [u_in.id], payload["rows"].map { |r| r["id"] }
  end

  test "scoreboard with outside_contest blocks access during contest mode" do
    sign_in_as("admin", "admin")
    set_grader_config("system.scoreboard_enabled", "outside_contest")

    set_grader_config("system.mode", "standard")
    get scoreboard_path
    assert_response :success

    set_grader_config("system.mode", "contest")
    get scoreboard_path
    assert_redirected_to root_path
  end

  test "contest view enables absent contestants filter while report max_score does not" do
    sign_in_as("admin", "admin")
    contest = Contest.create!(name: "view_filter_test", enabled: true, start: 1.hour.ago, stop: 2.hours.from_now)

    get view_contest_path(contest)
    assert_response :success
    assert_select "[data-datatables--init-score-table-enable-absent-filter-value='true']"

    get max_score_report_path
    assert_response :success
    assert_select "[data-datatables--init-score-table-enable-absent-filter-value='false']"
  end

  test "layout sets data-bs-theme dark for dark themes and light for light themes" do
    admin = users(:admin)
    set_grader_config("gimmicks.theme_selector_enabled", "true")
    sign_in_as("admin", "admin")

    admin.update!(theme: "premium")
    get scheduled_tasks_path
    assert_response :success
    assert_select "html[data-theme='premium'][data-bs-theme='dark']"

    admin.update!(theme: "ocean")
    get scheduled_tasks_path
    assert_response :success
    assert_select "html[data-theme='ocean'][data-bs-theme='light']"
  end
end
