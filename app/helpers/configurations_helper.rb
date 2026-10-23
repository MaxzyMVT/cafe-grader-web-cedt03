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

  SYSTEM_SUBGROUPS = [
    {
      title: 'Mode & Access Control',
      icon: 'tune',
      keys: %w[
        system.mode
        system.single_user_mode
        system.multicontests
        system.use_problem_group
      ]
    },
    {
      title: 'Scoreboard & Scoring',
      icon: 'leaderboard',
      keys: %w[
        system.scoreboard_enabled
        system.scoreboard_view_level
        system.scoreboard_public_accessible
        system.scoreboard_include_admins
        system.group_score_type
        system.statistic_include_admins
      ]
    },
    {
      title: 'Student Features & Assistance',
      icon: 'psychology',
      keys: %w[
        system.llm_assist
        system.message_enabled
        system.user_setting_enabled
      ]
    },
    {
      title: 'Registration & Administration',
      icon: 'mail',
      keys: %w[
        system.online_registration
        system.online_registration.smtp
        system.online_registration.from
        system.admin_email
      ]
    }
  ].freeze

  def dynamic_description_for(key, current_value)
    cfg = DYNAMIC_DESCRIPTIONS[key]
    return nil unless cfg
    base = cfg['base']
    choice_desc = cfg['choices'][current_value] || current_value
    "#{base} Currently: #{choice_desc}"
  end

  def config_group_for(conf)
    return 'gimmicks' if conf.key == 'system.theme_selector_enabled'
    conf.key[0...(conf.key.index('.'))]
  end

  def subgrouped_configurations_for(group, configurations)
    confs = configurations.select { |c| config_group_for(c) == group }

    if group == 'system'
      confs_by_key = confs.index_by(&:key)
      used_keys = Set.new

      subgroups = SYSTEM_SUBGROUPS.map do |sub|
        items = sub[:keys].filter_map { |k| confs_by_key[k] }
        used_keys.merge(sub[:keys])
        { title: sub[:title], icon: sub[:icon], items: items }
      end.reject { |sub| sub[:items].empty? }

      # Any remaining system settings not explicitly placed in predefined subgroups
      remaining = confs.reject { |c| used_keys.include?(c.key) }
      if remaining.any?
        subgroups << { title: 'Other System Settings', icon: 'settings', items: remaining }
      end

      subgroups
    else
      [{ title: nil, icon: nil, items: confs }]
    end
  end
end
