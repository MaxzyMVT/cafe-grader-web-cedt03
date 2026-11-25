require "test_helper"

class ScoreboardAndContestViewTest < ActionDispatch::IntegrationTest
  setup do
    GraderConfiguration.find_or_create_by!(key: "system.scoreboard_enabled") do |c|
      c.value_type = "boolean"
      c.value = "true"
    end.update!(value: "true")
    GraderConfiguration.find_or_create_by!(key: "system.scoreboard_view_level") do |c|
      c.value_type = "string"
      c.value = "all"
    end.update!(value: "all")
    GraderConfiguration.find_or_create_by!(key: "gimmicks.theme_selector_enabled") do |c|
      c.value_type = "boolean"
      c.value = "true"
    end.update!(value: "true")
    reset_grader_config_cache
  end

  test "scoreboard renders modern structure in individual and group modes" do
    sign_in_as("admin", "admin")

    get scoreboard_path
    assert_response :success
    assert_select ".scoreboard-card"
    assert_select ".scoreboard-scroll-wrapper"
    assert_select "#scoreboard-search"

    get scoreboard_path(mode: "group")
    assert_response :success
    assert_select ".scoreboard-card"
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
