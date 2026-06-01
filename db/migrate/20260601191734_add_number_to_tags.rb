class AddNumberToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :number, :integer
    reversible do |dir|
      dir.up do
        Tag.reset_column_information
        Tag.order(:id).each_with_index do |tag, idx|
          tag.update_columns(number: idx + 1)
        end
      end
    end
  end
end
