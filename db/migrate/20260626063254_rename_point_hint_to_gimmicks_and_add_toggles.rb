class RenamePointHintToGimmicksAndAddToggles < ActiveRecord::Migration[8.0]
  def up
    # Rename point_hint. to gimmicks.
    execute("UPDATE grader_configurations SET `key` = REPLACE(`key`, 'point_hint.', 'gimmicks.') WHERE `key` LIKE 'point_hint.%'")

    # Create new toggles
    GraderConfiguration.find_or_create_by!(key: 'gimmicks.enable_first_bloods') do |c|
      c.value_type = 'boolean'
      c.value = 'true'
      c.description = 'Enable/Disable First Bloods globally'
    end
    GraderConfiguration.find_or_create_by!(key: 'gimmicks.enable_submission_limits') do |c|
      c.value_type = 'boolean'
      c.value = 'true'
      c.description = 'Enable/Disable Submission Limits globally'
    end

    # Update description of system.group_score_type
    config = GraderConfiguration.find_by(key: 'system.group_score_type')
    config&.update!(description: "Determines what will show on the main list page regarding the maximum score of the user's group.")
  end

  def down
    # Remove new toggles
    GraderConfiguration.find_by(key: 'gimmicks.enable_first_bloods')&.destroy
    GraderConfiguration.find_by(key: 'gimmicks.enable_submission_limits')&.destroy

    # Rename gimmicks. back to point_hint.
    execute("UPDATE grader_configurations SET `key` = REPLACE(`key`, 'gimmicks.', 'point_hint.') WHERE `key` LIKE 'gimmicks.%'")
  end
end
