class Announcement < ApplicationRecord
  has_one_attached :file
  belongs_to :group, optional: true
  validates :title, presence: true

  scope :published, -> { where(published: true) }
  scope :frontpage, -> { published.where(frontpage: true) }
  scope :mainpage, -> { published.where(frontpage: false) }
  scope :default_order, -> { order(number: :desc).order(created_at: :desc) }
  scope :consider_contest, -> { GraderConfiguration.contest_mode? ? all : where(contest_only: false) }

  before_create :assign_default_number

  def assign_default_number
    self.number ||= (Announcement.maximum(:number) || 0) + 1
  end

  def self.set_announcement_number(announcement, target_pos)
    announcements = Announcement.order(number: :desc, created_at: :desc).to_a
    announcements.delete(announcement)
    announcements.insert(target_pos - 1, announcement)
    
    num = announcements.size
    announcements.each do |a|
      a.update_columns(number: num)
      num -= 1
    end
  end

  scope :viewable_by_user, ->(user) {
    return published.consider_contest.where(group: nil).or(where(group: user.groups_for_action(:submit)))
  }

  scope :editable_by_user, ->(user) {
    if user.admin? || user.problem_setter?
      # admin or setter can edit any announcement
      return all
    elsif user.groups_for_action(:edit).any?
      # for editor, can only edit announcements of their editable groups
      return where(group: user.groups_for_action(:edit)).or(where(group: nil))
    else
      return none
    end
  }
end
