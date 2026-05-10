class ScoreboardController < ApplicationController
  before_action :check_public_scoreboard_access

  def index
    # Fetch all enabled users, problems that are available/reportable
    # For now we fetch all problems for simplicity
    @problems = Problem.available.order(:date_added)

    # Fetch users, but depending on group toggle, we might need groups
    @users = User.where(enabled: true)
    
    unless GraderConfiguration['system.scoreboard_include_admins']
      admin_ids = User.joins(:roles).where(roles: { name: 'admin' }).pluck(:id)
      @users = @users.where.not(id: admin_ids)
    end
    
    # Mode toggle: individual vs groups
    @mode = params[:mode] == 'group' ? 'group' : 'individual'
    
    # Calculate scores using the robust max_score_report scope
    # We now fetch raw max_score for problem cells and total deductions separately
    report_records = Submission.where(user: @users, problem: @problems).max_score_report(@problems, nil, nil)
    
    @scores = Hash.new { |h,k| h[k] = {} }
    report_records.each do |record|
      @scores[record.user_id][record.problem_id] = record.max_score.to_f
    end
    
    # Total deductions per user (all reveals)
    @user_deductions = CommentReveal.where(user: @users).joins(:comment).group(:user_id).sum('comments.cost')

    if @mode == 'individual'
      @leaderboard = @users.map do |u|
        raw_sum = 0
        @problems.each do |p|
          raw_sum += @scores[u.id][p.id] || 0
        end
        deducted = @user_deductions[u.id] || 0
        { user: u, total_score: [0.0, raw_sum - deducted].max, deducted_score: deducted }
      end
      # Sort by total_score desc, then by name
      @leaderboard.sort_by! { |entry| [-entry[:total_score], entry[:user].full_name.to_s.downcase] }
      
      # Assign dense ranks
      current_rank = 1
      previous_score = nil
      @leaderboard.each_with_index do |entry, index|
        if previous_score != entry[:total_score]
          current_rank = index + 1
          previous_score = entry[:total_score]
        end
        entry[:rank] = current_rank
      end
      
      # Optional name sorting
      if params[:sort] == 'name'
        @leaderboard.sort_by! { |entry| entry[:user].full_name.to_s.downcase }
      end
    else
      # Group mode
      @groups = Group.all
      @leaderboard = @groups.map do |g|
        group_users = g.users.where(enabled: true)
        group_total = 0
        group_deducted = 0
        group_members = group_users.map do |u|
          user_raw_total = 0
          @problems.each do |p|
            user_raw_total += @scores[u.id][p.id] || 0
          end
          user_deducted = @user_deductions[u.id] || 0
          user_final = [0.0, user_raw_total - user_deducted].max
          group_total += user_final
          group_deducted += user_deducted
          { user: u, total_score: user_final, deducted_score: user_deducted }
        end
        group_members.sort_by! { |m| [-m[:total_score], m[:user].full_name.to_s.downcase] }
        
        { group: g, total_score: group_total, deducted_score: group_deducted, members: group_members }
      end
      @leaderboard.sort_by! { |entry| [-entry[:total_score], entry[:group].name.to_s.downcase] }
      
      current_rank = 1
      previous_score = nil
      @leaderboard.each_with_index do |entry, index|
        if previous_score != entry[:total_score]
          current_rank = index + 1
          previous_score = entry[:total_score]
        end
        entry[:rank] = current_rank
        
        # Rank inside group members
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
      end
    end

    render layout: 'application'
  end

  private

  def check_public_scoreboard_access
    unless GraderConfiguration['system.scoreboard_enabled']
      redirect_to root_path, alert: 'Scoreboard is currently disabled.'
      return
    end

    level = GraderConfiguration['system.scoreboard_view_level'] || 'user'
    case level
    when 'all'
      # anyone can see
    when 'user'
      check_valid_login
    when 'admin'
      check_valid_login
      unless @current_user.admin?
        redirect_to root_path, alert: 'Only admins can access the scoreboard.'
      end
    end
  end
end
