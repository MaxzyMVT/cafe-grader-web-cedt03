class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  enum :kind, {hint: 0, solution: 1, comment: 2, llm_assist: 3}
  enum :status, {ok: 0, processing: 1, error: 2} # used to indicate whether this comment is waiting to be updated (such as from AI API call)

  has_many :comment_reveals
  has_many :users_who_revealed, through: :comment_reveals, source: :user # More descriptive name

  # limit to only HINT
  HINT_KIND = self.kinds.select { |k| k[0...4] == 'hint' }

  scope :chargeable_for, ->(user, time_range = nil) {
    if time_range
      where(user: user, updated_at: time_range, kind: ['hint', 'llm_assist'])
    else
      where(user: user, kind: ['hint', 'llm_assist'])
    end
  }

  scope :hint_reveal_for_problems, ->(problems, time_range = nil) {
    if time_range
      Comment.joins(:comment_reveals)
        .where(commentable: problems, commentable_type: 'Problem')
        .where(comment_reveals: {created_at: time_range})
        .group('comment_reveals.user_id', :commentable_id)
    else
      Comment.joins(:comment_reveals)
        .where(commentable: problems, commentable_type: 'Problem')
        .group('comment_reveals.user_id', :commentable_id)
    end
  }

  scope :hints, -> { where(kind: HINT_KIND.keys) }

  scope :llm_assists_for_submissions, ->(submissions) {
    Comment.where(commentable: submissions, commentable_type: 'Submission').group(:commentable_id)
  }

  validates :title, presence: true
  
  def is_acquired?(user = nil)
    # if it is already selected by comments_with_reveal_status
    return self.is_acquired == 1 if self.respond_to?(:is_acquired)
    return false if user.nil?
    comment_reveals.where(user: user, is_success: true).exists?
  end

  def to_label
    "#{kind}: #{title}"
  end

  def available_in_contest?(contest, contest_user)
    return true if available_after.blank? || available_after <= 0
    return true unless GraderConfiguration.contest_mode? && contest

    end_time = contest.stop + (contest_user&.extra_time_second || 0).seconds
    return true if Time.zone.now > end_time

    user_start_time = contest.start - (contest_user&.start_offset_second || 0).seconds
    Time.zone.now >= user_start_time + available_after.seconds
  end

  # check if the user can acquire this comment
  # This check both the logic of commentable, the contest, and the user itself
  def acquirable_by?(user, contest = nil, contest_user = nil)
    # basic user logic
    return false unless user.present? && user.enabled?

    # timing check
    c = contest || (GraderConfiguration.contest_mode? ? user.contests.where(enabled: true).order(:stop).first : nil)
    cu = contest_user || (c ? c.contests_users.where(user: user).take : nil)
    return false unless available_in_contest?(c, cu)

    # call the specific model logic
    commentable.comment_reveal_prerequisite_satisfied?(self, user)
  end

  def self.cost_summary_for(user, contest)
    comments = chargeable_for(user, (contest.start)..(contest.stop))
    {
      count: comments.count,
      total_cost: comments.sum(:cost)
    }
  end

  # automatically set the title to "Hint xxx"
  def set_default_hint_title
    return if title.present?

    # Find the highest existing hint number for the same problem
    scope = Comment.where(commentable: self.commentable).where("title LIKE ?", "Hint %")

    # The SQL fragment extracts the number after "Hint " and converts it to an integer.
    last_hint_number = scope.maximum("CAST(SUBSTRING(title FROM 6) AS UNSIGNED)")

    # Calculate the next number. If no hints exist, it defaults to 0 + 1 = 1.
    next_number = (last_hint_number || 0) + 1

    self.title = "Hint #{next_number}"
  end
end
