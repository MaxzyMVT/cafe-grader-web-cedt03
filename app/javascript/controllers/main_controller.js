import { Controller } from "@hotwired/stimulus"
import { rowFieldToggle } from "mixins/row_field_toggle";

export default class extends rowFieldToggle(Controller) {

  static targets = ["usersCommand", "userForm", "userFormUserID", "userFormCommand" ,
                    "problemsCommand", "problemForm", "problemFormProblemID", "problemFormCommand" ,
                    "toggleForm",
                   ]

  connect() {
  }

  setActiveTopic(event) {
    const clickedBadge = event.currentTarget;
    
    // Toggle active-topic class on the clicked badge
    clickedBadge.classList.toggle('active-topic');

    const badges = this.element.querySelectorAll(".topic-badge");
    const activeBadges = this.element.querySelectorAll(".topic-badge.active-topic");
    const hasActive = activeBadges.length > 0;

    badges.forEach((badge) => {
      if (badge.classList.contains('active-topic')) {
        badge.classList.add('active');
        badge.classList.remove('opacity-50');
      } else {
        if (hasActive) {
          badge.classList.remove('active');
          badge.classList.add('opacity-50');
        } else {
          badge.classList.remove('active');
          badge.classList.remove('opacity-50');
        }
      }
    });

    // Generate the regex pattern to match any of the active badges
    const activeNames = Array.from(activeBadges).map(b => b.textContent.trim());
    if (activeNames.length === 0) {
      table.column(6).search('').draw();
    } else {
      let pattern = activeNames.map(t => $.fn.dataTable.util.escapeRegex(t)).join('|');
      table.column(6).search(pattern, true, false).draw();
    }
  }


}
