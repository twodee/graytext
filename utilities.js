function autosize(id) {
  var element = document.getElementById(id);
  element.width = element.contentWindow.document.body.scrollWidth;
  element.height = element.contentWindow.document.body.scrollHeight;
}

function scramble(list) {
  for (var i = list.children.length; i >= 0; --i) {
    list.appendChild(list.children[Math.random() * i | 0]);
  }
}

$(function() {
  $('.scrambled').sortable();
  $('.scrambled').disableSelection();
  $('.scrambled').each(function() {
    scramble(this);
  });

  $('.scramble').click(function() {
    scramble($(this).prev()[0]);
  });
});

$(function() {
  $('.togglee').css('display', 'none');
  $('.toggler').click(function() {
    if ($(this).next().css('display') == 'none') {
      $(this).next().slideDown();
    } else {
      $(this).next().slideUp();
    }
    return false;
  });
});

