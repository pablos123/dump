// Delete all ratings of the diary page and go the next page.
document.querySelectorAll(".remove-rating.tooltip").forEach( e => e.click() ); document.querySelector("a.next").click()

// Delete all likes of a diary page and go the next page.
// Delete all likes of a watched films page and go the next page.
document.querySelectorAll("span.ajax-click-action.icon-liked").forEach( e => e.click() ); document.querySelector("a.next").click()

// Delete all ratings of a watched films page after you hover the mouse in all of the movies and go the next page.
document.querySelectorAll(".replace.menu-link.icon").forEach( e => e.click() ); document.querySelectorAll("button.removetrigger").forEach( e => e.click() ); document.querySelector("a.next").click()
