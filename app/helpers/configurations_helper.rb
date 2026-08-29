module ConfigurationsHelper
  DYNAMIC_DESCRIPTIONS = {
    'system.mode' => {
      'base' => 'Determines the operation mode of the system.',
      'choices' => {
        'standard' => 'Standard mode (individual tasks and submission view)',
        'contest' => 'Contest mode (time-bound contest dashboard, restrict task visibility)',
        'indv-contest' => 'Individual Contest mode (timer starts individually per user on their first view)',
        'analysis' => 'Analysis mode (viewing other users\' code is allowed for learning/review)'
      }
    },
    'system.group_score_type' => {
      'base' => 'Determines how the maximum score of each user\'s group is calculated and shown on scoreboard.',
      'choices' => {
        'group_sum' => 'Group Sum (summing up all members\' scores)',
        'group_max' => 'Group Max (the max of all members\' scores for each problem, showing own group\'s max score on problem list)'
      }
    },
    'system.scoreboard_view_level' => {
      'base' => 'Who can view the real-time scoreboard.',
      'choices' => {
        'all' => 'Anyone (public) can view the scoreboard',
        'user' => 'Only logged-in users can view the scoreboard',
        'admin' => 'Only admins and problem setters can view the scoreboard'
      }
    }
  }

  def dynamic_description_for(key, current_value)
    cfg = DYNAMIC_DESCRIPTIONS[key]
    return nil unless cfg
    base = cfg['base']
    choice_desc = cfg['choices'][current_value] || current_value
    "#{base} Currently: #{choice_desc}"
  end
end
