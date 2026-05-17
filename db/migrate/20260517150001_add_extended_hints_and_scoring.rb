class AddExtendedHintsAndScoring < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :available_after, :integer, default: 0
    add_column :problems, :first_n_bloods, :integer, default: 0
  end
end
