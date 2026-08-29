require "test_helper"

class ContestTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid contest fixture" do
    assert contests(:contest_a).valid?
  end

  test "name must be present" do
    contest = Contest.new(enabled: true)
    assert_not contest.valid?
    assert contest.errors[:name].any?
  end

  test "name must be unique" do
    contest = Contest.new(name: "contest_a")
    assert_not contest.valid?
    assert contest.errors[:name].any?
  end

  test "name must match format" do
    contest = Contest.new(name: "bad name!")
    assert_not contest.valid?
    assert contest.errors[:name].any?
  end

  # --- Scopes ---

  test "enabled scope returns only enabled contests" do
    enabled = Contest.enabled
    assert_includes enabled, contests(:contest_a)
    assert_includes enabled, contests(:contest_b)
    assert_not_includes enabled, contests(:contest_c)
  end

  # --- Methods ---

  test "add_users adds new users and skips existing" do
    contest = contests(:contest_a)
    john = users(:john)    # not in contest_a
    james = users(:james)  # already in contest_a via fixture

    result = contest.add_users(User.where(id: [john.id, james.id]))
    assert_equal 1, result.added    # john added
    assert_equal 1, result.skipped  # james skipped
  end

  test "add_users with empty returns zero" do
    contest = contests(:contest_a)
    result = contest.add_users(nil)
    assert_equal 0, result.added
  end

  test "add_problems_and_assign_number adds problems" do
    contest = contests(:contest_c)
    prob = problems(:prob_add)
    result = contest.add_problems_and_assign_number(Problem.where(id: prob.id))
    assert_equal 1, result.added
    assert_equal 0, result.skipped
  end

  test "add_problems_and_assign_number skips existing" do
    contest = contests(:contest_c)
    prob = problems(:prob_add)
    # First add prob_add
    contest.add_problems_and_assign_number(Problem.where(id: prob.id))
    contest.save!
    contest.reload

    # Try to add same problem again
    result = contest.add_problems_and_assign_number(Problem.where(id: prob.id))
    assert_equal 0, result.added
    assert_equal 1, result.skipped
  end

  test "contest_status returns correct status" do
    # contest_a started 1 hour ago, ends in 3 hours
    assert_equal :during, contests(:contest_a).contest_status

    # contest_c ended 1 day ago
    assert_equal :ended, contests(:contest_c).contest_status

    # Test pre/post contest seconds
    contest = contests(:contest_a)
    contest.start = 10.minutes.from_now
    contest.stop = 20.minutes.from_now
    
    # Case 1: no buffer (returns :later since now is before start)
    contest.pre_contest_seconds = 0
    assert_equal :later, contest.contest_status
    
    # Case 2: inside pre contest buffer
    contest.pre_contest_seconds = 15 * 60 # 15 minutes
    assert_equal :pre, contest.contest_status

    # Case 3: inside post contest buffer
    contest.start = 20.minutes.ago
    contest.stop = 10.minutes.ago
    contest.post_contest_seconds = 15 * 60 # 15 minutes
    assert_equal :post, contest.contest_status

    # Case 4: after post contest buffer
    contest.post_contest_seconds = 5 * 60 # 5 minutes (ended 10 mins ago)
    assert_equal :ended, contest.contest_status
  end

  test "get_next_name generates unique name" do
    contest = contests(:contest_a)
    name = contest.get_next_name
    assert_not_equal "contest_a", name
    assert_match(/contest_a_\d+/, name)
  end

  test "check_in_interval returns 60 seconds" do
    assert_equal 60, Contest.check_in_interval
  end

  # --- Associations ---

  test "contest has users through contests_users" do
    contest = contests(:contest_a)
    assert_includes contest.users, users(:james)
  end
end
