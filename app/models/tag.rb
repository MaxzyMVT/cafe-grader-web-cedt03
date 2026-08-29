class Tag < ApplicationRecord
  validates :name, presence: true

  enum :kind, {normal: 0, topic: 1, llm_prompt: 2, viva_grounding: 3}
  has_many :problems_tags, class_name: 'ProblemTag'
  has_many :problems, through: :problems_tags

  has_many_attached :files

  before_create :assign_default_number

  def assign_default_number
    self.number ||= (Tag.maximum(:number) || 0) + 1
  end

  def self.set_tag_number(tag, number)
    num = 1
    Tag.where.not(id: tag.id).order(:number).each do |t|
      offset = (num >= number) ? 1 : 0
      t.update_columns(number: num + offset)
      num += 1
    end
    tag.update_columns(number: [Tag.count, [1, number.round].max].min)
  end

  def grounding_payload
    return params.to_s unless files.attached?

    extracted = files.map { |f| f.metadata['extracted_text'].to_s }.reject(&:blank?)
    [params.to_s, *extracted].reject(&:blank?).join("\n\n")
  end
end
