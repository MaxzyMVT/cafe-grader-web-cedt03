class AddNumberToProblems < ActiveRecord::Migration[8.0]
  def up
    add_column :problems, :number, :integer, default: 0
    # Assign sequential numbers to existing problems
    Problem.order(:id).each_with_index do |problem, index|
      problem.update_columns(number: index + 1)
    end
  end

  def down
    remove_column :problems, :number
  end
end
