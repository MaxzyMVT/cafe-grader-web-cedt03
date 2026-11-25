class ScoreboardController < ApplicationController
  before_action :check_public_scoreboard_access

  def index
    @contest_mode = GraderConfiguration.contest_mode?
    @enabled_contests = @contest_mode ? Contest.where(enabled: true).order(:id).to_a : []
    enabled_contest_ids = @enabled_contests.map(&:id)

    # Fetch problems (scoped to enabled contests when in contest mode)
    if @contest_mode
      @problems = if enabled_contest_ids.any?
                    Problem.available
                           .includes(:live_dataset)
                           .joins(:contests_problems)
                           .where(contests_problems: { contest_id: enabled_contest_ids, enabled: true })
                           .group('problems.id')
                           .order(Arel.sql('MIN(contests_problems.number) ASC, problems.name ASC'))
                           .to_a
                  else
                    []
                  end
    else
      @problems = Problem.available.includes(:live_dataset).visible_to_user(@current_user).default_order.to_a
    end

    # Precompute effective full score & raw_sum testcase counts once (avoids N+1 queries)
    raw_sum_dataset_ids = @problems.filter_map { |p| p.live_dataset_id if p.live_dataset&.st_raw_sum? }
    dataset_tc_counts = raw_sum_dataset_ids.any? ? Testcase.where(dataset_id: raw_sum_dataset_ids).group(:dataset_id).count : {}
    @problem_full_scores = {}
    @problem_tc_counts = {}
    @problems.each do |p|
      tc_count = if p.live_dataset&.st_raw_sum?
                   dataset_tc_counts[p.live_dataset_id].to_i
                 elsif p.live_dataset_id
                   nil
                 else
                   0
                 end
      @problem_tc_counts[p.id] = tc_count
      @problem_full_scores[p.id] = if p.live_dataset&.st_raw_sum?
                                     tc_count > 0 ? tc_count : (p.full_score || 0)
                                   else
                                     p.full_score || 0
                                   end
    end

    # Precompute associations for problem-user visibility check in scoreboard cells
    @problem_groups = Hash.new { |h, k| h[k] = Set.new }
    @problems_with_groups = Set.new
    @user_groups = Hash.new { |h, k| h[k] = Set.new }
    @problem_contests = Hash.new { |h, k| h[k] = Set.new }
    @user_contests = Hash.new { |h, k| h[k] = Set.new }

    if @contest_mode
      if enabled_contest_ids.any?
        ContestProblem.where(contest_id: enabled_contest_ids, enabled: true)
                      .pluck(:problem_id, :contest_id)
                      .each { |pid, cid| @problem_contests[pid] << cid }

        ContestUser.where(contest_id: enabled_contest_ids, enabled: true)
                   .pluck(:user_id, :contest_id)
                   .each { |uid, cid| @user_contests[uid] << cid }
      end
    else
      enabled_group_ids = Group.where(enabled: true).pluck(:id).to_set
      @problems_with_groups = GroupProblem.distinct.pluck(:problem_id).to_set

      if enabled_group_ids.any?
        GroupProblem.where(enabled: true, group_id: enabled_group_ids.to_a)
                    .pluck(:problem_id, :group_id)
                    .each { |pid, gid| @problem_groups[pid] << gid }

        GroupUser.where(enabled: true, group_id: enabled_group_ids.to_a)
                 .pluck(:user_id, :group_id)
                 .each { |uid, gid| @user_groups[uid] << gid }
      end
    end

    @admin_setter_ids = User.joins(:roles).where(roles: { name: ['admin', 'problem_setter'] }).pluck(:id).to_set

    # Fetch users (scoped to enabled contests when in contest mode)
    @users = User.where(enabled: true)
    if @contest_mode
      @users = @users.where(id: @user_contests.keys)
    end

    unless GraderConfiguration['system.scoreboard_include_admins']
      @users = @users.where.not(id: @admin_setter_ids.to_a)
    end
    @users = @users.to_a

    # Mode toggle: individual vs groups
    @mode = params[:mode] == 'group' ? 'group' : 'individual'

    prob_ids = @problems.map(&:id)
    user_ids = @users.map(&:id)

    @scores = Hash.new { |h, k| h[k] = {} }
    @zero_score_passes = Hash.new { |h, k| h[k] = {} }
    @user_deductions = Hash.new(0)
    @first_blood_users = {}
    user_completion_times = {}
    passed_counts = Hash.new(0)

    enable_penalty = GraderConfiguration.enable_penalty?
    enable_bonus = GraderConfiguration.enable_bonus?
    show_first_bloods = GraderConfiguration.show_first_bloods?

    if prob_ids.any? && user_ids.any?
      # Calculate scores using the robust max_score_report scope
      report_records = Submission.where(user_id: user_ids, problem_id: prob_ids)
                                 .max_score_report(Problem.where(id: prob_ids), nil, nil)
      report_records.each do |record|
        @scores[record.user_id][record.problem_id] = record.max_score.to_f
      end

      # For 0-score problems, check if there is any submission that passes all test cases
      zero_score_problems = @problems.select { |p| @problem_full_scores[p.id] == 0 }
      zero_score_prob_ids = zero_score_problems.map(&:id)
      passing_zero_sub_ids = []

      if zero_score_problems.any?
        zero_ds_ids = zero_score_problems.filter_map(&:live_dataset_id)
        zero_tc_counts = zero_ds_ids.any? ? Testcase.where(dataset_id: zero_ds_ids).group(:dataset_id).count : {}
        zero_prob_by_id = zero_score_problems.index_by(&:id)

        zero_subs = Submission.where(user_id: user_ids, problem_id: zero_score_prob_ids, status: 'done', viva_archived_at: nil)
                              .select(:id, :user_id, :problem_id, :grader_comment)
        zero_subs.each do |s|
          prob = zero_prob_by_id[s.problem_id]
          next unless prob
          tc_count = prob.live_dataset_id ? zero_tc_counts[prob.live_dataset_id].to_i : 0
          clean_gc = s.grader_comment.to_s.gsub(/[\[\]\s]/, '')
          passed = (tc_count == 0) || clean_gc.match?(/\A[PS]+\z/)
          if passed
            @zero_score_passes[s.user_id][s.problem_id] = true
            passing_zero_sub_ids << s.id
          end
        end
      end

      # Total deductions per user (only needed if penalty enabled)
      if enable_penalty
        hint_deductions = CommentReveal.where(user_id: user_ids)
                                       .joins("INNER JOIN comments ON comments.id = comment_reveals.comment_id AND comments.commentable_type = 'Problem'")
                                       .where(comments: { commentable_id: prob_ids })
                                       .group(:user_id).sum('comments.cost')

        submission_deductions = CommentReveal.where(user_id: user_ids)
                                             .joins("INNER JOIN comments ON comments.id = comment_reveals.comment_id AND comments.commentable_type = 'Submission'")
                                             .joins("INNER JOIN submissions ON submissions.id = comments.commentable_id")
                                             .where(submissions: { problem_id: prob_ids })
                                             .group(:user_id).sum('comments.cost')

        hint_deductions.each { |uid, cost| @user_deductions[uid] += cost }
        submission_deductions.each { |uid, cost| @user_deductions[uid] += cost }
      end

      # Calculate First Blood bonuses once per problem (only when shown)
      if show_first_bloods
        @problems.each do |p|
          if p.bonus_first_blood.to_f != 0
            n = p.respond_to?(:first_n_bloods) ? p.first_n_bloods : 0
            @first_blood_users[p.id] = p.first_n_blood_users(n).map(&:id)
          else
            @first_blood_users[p.id] = []
          end
        end
      end

      # Fetch completion times and passed counts for sorting ties (earliest to reach final score)
      max_pts_sub = Submission.where(user_id: user_ids, problem_id: prob_ids)
      if passing_zero_sub_ids.any?
        max_pts_sub = max_pts_sub.where("submissions.points > 0 OR submissions.id IN (?)", passing_zero_sub_ids)
      else
        max_pts_sub = max_pts_sub.where("submissions.points > 0")
      end
      max_pts_sub = max_pts_sub.group(:user_id, :problem_id).select('user_id, problem_id, MAX(points) as max_pts')

      first_bests = Submission.where(user_id: user_ids, problem_id: prob_ids)
                              .joins("INNER JOIN (#{max_pts_sub.to_sql}) mp ON submissions.user_id = mp.user_id AND submissions.problem_id = mp.problem_id AND submissions.points = mp.max_pts")
                              .group(:user_id, :problem_id)
                              .select('submissions.user_id, submissions.problem_id, MIN(submissions.submitted_at) as first_best_time')

      user_completion_times = Submission.from("(#{first_bests.to_sql}) fb")
                                        .group('fb.user_id')
                                        .select('fb.user_id, MAX(fb.first_best_time) as last_completed_time')
                                        .each_with_object({}) { |r, h| h[r.user_id] = r.last_completed_time }

      best_subs = Submission.where(user_id: user_ids, problem_id: prob_ids)
                            .joins("INNER JOIN (#{first_bests.to_sql}) fb ON submissions.user_id = fb.user_id AND submissions.problem_id = fb.problem_id AND submissions.submitted_at = fb.first_best_time")
                            .select('submissions.user_id, submissions.grader_comment')

      best_subs.each do |sub|
        comment = sub.grader_comment.to_s.gsub(/[\[\]\s]/, '')
        if !comment.blank? && comment.match?(/\A[PS]*\z/)
          passed_counts[sub.user_id] += 1
        end
      end
    end

    # Precompute per-user bonus map so inner loops are O(1)
    user_bonuses = Hash.new(0.0)
    if enable_bonus && show_first_bloods
      @problems.each do |p|
        bonus_val = p.bonus_first_blood.to_f
        next if bonus_val == 0
        (@first_blood_users[p.id] || []).each { |uid| user_bonuses[uid] += bonus_val }
      end
    end

    if @mode == 'individual'
      @leaderboard = @users.map do |u|
        user_scores = @scores[u.id]
        raw_sum = 0.0
        @problems.each { |p| raw_sum += user_scores[p.id] || 0.0 }
        deducted = enable_penalty ? (@user_deductions[u.id] || 0) : 0
        bonus = user_bonuses[u.id]

        { user: u, total_score: [0.0, raw_sum - deducted + bonus].max, deducted_score: deducted, bonus_score: bonus }
      end

      @leaderboard.sort_by! do |entry|
        uid = entry[:user].id
        comp_time = user_completion_times[uid] || Time.zone.at(2147483647)
        pass_count = passed_counts[uid] || 0
        [-entry[:total_score], comp_time.to_i, -pass_count, entry[:user].full_name.to_s.downcase]
      end

      current_rank = 1
      previous_score = nil
      @leaderboard.each_with_index do |entry, index|
        if previous_score != entry[:total_score]
          current_rank = index + 1
          previous_score = entry[:total_score]
        end
        entry[:rank] = current_rank
      end

      if params[:sort] == 'name'
        @leaderboard.sort_by! { |entry| [entry[:user].full_name.to_s.downcase, -entry[:total_score]] }
      end
    else
      # Group mode
      allowed_users_by_id = @users.reject { |u| @admin_setter_ids.include?(u.id) }.index_by(&:id)
      @groups = Group.where(enabled: true).to_a
      @group_score_type = GraderConfiguration['system.group_score_type'] || 'group_sum'

      # Batch-fetch group memberships
      members_by_group = Hash.new { |h, k| h[k] = [] }
      if @groups.any? && allowed_users_by_id.any?
        GroupUser.where(group_id: @groups.map(&:id), enabled: true, user_id: allowed_users_by_id.keys)
                 .pluck(:group_id, :user_id)
                 .each do |gid, uid|
          u = allowed_users_by_id[uid]
          members_by_group[gid] << u if u
        end
      end

      @leaderboard = @groups.filter_map do |g|
        group_users = members_by_group[g.id]
        next if @contest_mode && group_users.empty?

        group_total = 0.0
        group_deducted = 0.0
        group_bonus = 0.0
        group_members = group_users.map do |u|
          user_scores = @scores[u.id]
          user_raw_total = 0.0
          @problems.each { |p| user_raw_total += user_scores[p.id] || 0.0 }
          user_deducted = enable_penalty ? (@user_deductions[u.id] || 0) : 0
          user_bonus = user_bonuses[u.id]

          user_final = [0.0, user_raw_total - user_deducted + user_bonus].max
          group_total += user_final if @group_score_type == 'group_sum'
          group_deducted += user_deducted
          group_bonus += user_bonus
          { user: u, total_score: user_final, deducted_score: user_deducted, bonus_score: user_bonus }
        end

        if @group_score_type == 'group_max'
          group_raw_total = @problems.sum do |p|
            group_users.map { |u| @scores[u.id][p.id] || 0.0 }.max || 0.0
          end
          group_total = [0.0, group_raw_total - group_deducted + group_bonus].max
        end

        group_members.sort_by! do |m|
          uid = m[:user].id
          comp_time = user_completion_times[uid] || Time.zone.at(2147483647)
          pass_count = passed_counts[uid] || 0
          [-m[:total_score], comp_time.to_i, -pass_count, m[:user].full_name.to_s.downcase]
        end

        { group: g, total_score: group_total, deducted_score: group_deducted, bonus_score: group_bonus, members: group_members }
      end

      @leaderboard.sort_by! do |entry|
        group_member_uids = entry[:members].map { |m| m[:user].id }
        group_comp_time = group_member_uids.filter_map { |uid| user_completion_times[uid] }.max || Time.zone.at(2147483647)
        group_pass_count = group_member_uids.sum { |uid| passed_counts[uid] || 0 }
        [-entry[:total_score], group_comp_time.to_i, -group_pass_count, entry[:group].name.to_s.downcase]
      end

      current_rank = 1
      previous_score = nil
      @leaderboard.each_with_index do |entry, index|
        if previous_score != entry[:total_score]
          current_rank = index + 1
          previous_score = entry[:total_score]
        end
        entry[:rank] = current_rank

        member_rank = 1
        member_prev_score = nil
        entry[:members].each_with_index do |m, m_index|
          if member_prev_score != m[:total_score]
            member_rank = m_index + 1
            member_prev_score = m[:total_score]
          end
          m[:rank] = member_rank
        end
      end

      if params[:sort] == 'name'
        @leaderboard.sort_by! { |entry| entry[:group].name.to_s.downcase }
        @leaderboard.each do |entry|
          entry[:members].sort_by! { |m| [m[:user].full_name.to_s.downcase, -m[:total_score]] }
        end
      end
    end

    @scoreboard_payload = build_scoreboard_payload(
      enable_bonus: enable_bonus,
      enable_penalty: enable_penalty,
      show_first_bloods: show_first_bloods
    )

    respond_to do |format|
      format.html { render layout: 'application' }
      format.json { render json: @scoreboard_payload }
      format.csv {
        send_data generate_scoreboard_csv,
                  filename: "scoreboard_#{@mode}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                  type: 'text/csv; charset=utf-8'
      }
    end
  end

  private

  def build_scoreboard_payload(enable_bonus:, enable_penalty:, show_first_bloods:)
    prob_index = {}
    problems_data = @problems.each_with_index.map do |p, idx|
      prob_index[p.id] = idx
      fb_bonus = p.bonus_first_blood.to_f
      fb_n = p.respond_to?(:first_n_bloods) ? p.first_n_bloods.to_i : 0
      {
        id: p.id,
        name: p.name,
        full_name: p.full_name,
        full_score: @problem_full_scores[p.id] || 100,
        fb_bonus: show_first_bloods ? fb_bonus : 0.0,
        fb_n: show_first_bloods ? fb_n : 0,
        fb_users: show_first_bloods ? (@first_blood_users[p.id] || []) : [],
        scope_ids: (@contest_mode ? @problem_contests[p.id].to_a : @problem_groups[p.id].to_a),
        restricted: (@contest_mode ? true : @problems_with_groups.include?(p.id))
      }
    end

    rows = []
    if @mode == 'individual'
      @leaderboard.each do |entry|
        u = entry[:user]
        uid = u.id
        scores_map = {}
        @scores[uid].each do |pid, val|
          idx = prob_index[pid]
          scores_map[idx] = val if idx
        end
        zero_passes = []
        @zero_score_passes[uid].each_key do |pid|
          idx = prob_index[pid]
          zero_passes << idx if idx
        end

        rows << {
          t: 'u',
          id: uid,
          r: entry[:rank],
          n: u.full_name.to_s,
          sn: u.full_name.to_s.downcase,
          s: entry[:total_score],
          b: entry[:bonus_score].to_f,
          d: entry[:deducted_score].to_f,
          self: (@current_user && uid == @current_user.id) ? true : false,
          adm: @admin_setter_ids.include?(uid),
          sc: (@contest_mode ? @user_contests[uid].to_a : @user_groups[uid].to_a),
          p: scores_map,
          zp: zero_passes
        }
      end
    else
      @leaderboard.each do |entry|
        g = entry[:group]
        member_names = entry[:members].map { |m| m[:user].full_name.to_s.downcase }.join(' ')
        group_scores = {}
        @problems.each_with_index do |p, idx|
          val = if @group_score_type == 'group_max'
                  entry[:members].map { |m| @scores[m[:user].id][p.id] || 0.0 }.max || 0.0
                else
                  entry[:members].sum { |m| @scores[m[:user].id][p.id] || 0.0 }
                end
          group_scores[idx] = val if val.to_f > 0
        end

        rows << {
          t: 'g',
          id: g.id,
          r: entry[:rank],
          n: g.name.to_s,
          cnt: entry[:members].size,
          sn: "#{g.name.to_s.downcase} #{member_names}",
          s: entry[:total_score],
          b: entry[:bonus_score].to_f,
          d: entry[:deducted_score].to_f,
          sc: [g.id],
          p: group_scores
        }

        entry[:members].each do |m|
          u = m[:user]
          uid = u.id
          scores_map = {}
          @scores[uid].each do |pid, val|
            idx = prob_index[pid]
            scores_map[idx] = val if idx
          end
          zero_passes = []
          @zero_score_passes[uid].each_key do |pid|
            idx = prob_index[pid]
            zero_passes << idx if idx
          end

          rows << {
            t: 'm',
            id: uid,
            r: m[:rank],
            n: u.full_name.to_s,
            sn: "#{g.name.to_s.downcase} #{u.full_name.to_s.downcase}",
            s: m[:total_score],
            b: m[:bonus_score].to_f,
            d: m[:deducted_score].to_f,
            self: (@current_user && uid == @current_user.id) ? true : false,
            adm: @admin_setter_ids.include?(uid),
            sc: (@contest_mode ? @user_contests[uid].to_a : @user_groups[uid].to_a),
            p: scores_map,
            zp: zero_passes
          }
        end
      end
    end

    {
      mode: @mode,
      contest_mode: @contest_mode,
      contest_names: @enabled_contests.map(&:name),
      group_score_type: @group_score_type,
      enable_bonus: enable_bonus,
      enable_penalty: enable_penalty,
      show_first_bloods: show_first_bloods,
      total_entities: @leaderboard.size,
      problems: problems_data,
      rows: rows
    }
  end

  def check_public_scoreboard_access
    unless GraderConfiguration.scoreboard_enabled?
      redirect_to root_path, alert: 'Scoreboard is currently disabled.'
      return
    end

    level = GraderConfiguration['system.scoreboard_view_level'] || 'user'
    case level
    when 'all', 'public'
      # anyone can see
    when 'user'
      check_valid_login
    when 'admin'
      check_valid_login
      unless @current_user.admin? || @current_user.problem_setter?
        redirect_to root_path, alert: 'Only admins can access the scoreboard.'
      end
    end
  end

  def generate_scoreboard_csv
    require 'csv'
    CSV.generate(headers: true) do |csv|
      headers = ["Rank", "Name", "Sum"]
      headers << "Bonus" if GraderConfiguration.enable_bonus?
      headers << "Deducted" if GraderConfiguration.enable_penalty?
      @problems.each do |p|
        headers << "#{p.name} (#{@problem_full_scores[p.id] || 100})"
      end
      csv << headers

      if @mode == 'individual'
        @leaderboard.each do |entry|
          row = [
            entry[:rank],
            entry[:user].full_name,
            entry[:total_score]
          ]
          row << (entry[:bonus_score].to_f > 0 ? entry[:bonus_score] : nil) if GraderConfiguration.enable_bonus?
          row << (entry[:deducted_score].to_f > 0 ? entry[:deducted_score] : nil) if GraderConfiguration.enable_penalty?

          @problems.each do |p|
            if helpers.user_associated_with_problem?(entry[:user].id, p.id)
              row << (@scores[entry[:user].id][p.id] || 0)
            else
              row << "—"
            end
          end
          csv << row
        end
      else
        @leaderboard.each do |entry|
          row = [
            entry[:rank],
            "[Group] #{entry[:group].name}",
            entry[:total_score]
          ]
          row << (entry[:bonus_score].to_f > 0 ? entry[:bonus_score] : nil) if GraderConfiguration.enable_bonus?
          row << (entry[:deducted_score].to_f > 0 ? entry[:deducted_score] : nil) if GraderConfiguration.enable_penalty?

          @problems.each do |p|
            if helpers.group_associated_with_problem?(entry[:group].id, p.id)
              group_score = @group_score_type == 'group_max' ? (entry[:members].map { |m| @scores[m[:user].id][p.id] || 0 }.max || 0) : entry[:members].map { |m| @scores[m[:user].id][p.id] || 0 }.sum
              row << group_score
            else
              row << "—"
            end
          end
          csv << row

          entry[:members].each do |m|
            member_row = [
              m[:rank],
              "  - #{m[:user].full_name}",
              m[:total_score]
            ]
            member_row << (m[:bonus_score].to_f > 0 ? m[:bonus_score] : nil) if GraderConfiguration.enable_bonus?
            member_row << (m[:deducted_score].to_f > 0 ? m[:deducted_score] : nil) if GraderConfiguration.enable_penalty?
            @problems.each do |p|
              if helpers.user_associated_with_problem?(m[:user].id, p.id)
                member_row << (@scores[m[:user].id][p.id] || 0)
              else
                member_row << "—"
              end
            end
            csv << member_row
          end
        end
      end
    end
  end
end
