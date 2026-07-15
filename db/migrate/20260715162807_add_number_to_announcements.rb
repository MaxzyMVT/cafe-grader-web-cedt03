class AddNumberToAnnouncements < ActiveRecord::Migration[8.0]
  def change
    add_column :announcements, :number, :integer, default: 0

    reversible do |dir|
      dir.up do
        Announcement.order(created_at: :asc).each_with_index do |announcement, index|
          announcement.update_columns(number: index + 1)
        end
      end
    end
  end
end
