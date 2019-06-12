function autosize(id) {
  id = '#' + id;
  $(id).height($(id).contents().outerHeight());
  $(id).width($(id).contents().outerWidth());
}

function lineveil() {
  var tag = $(this).next();
  if (tag.css('display') == 'none') {
    tag.next().fadeOut(400, function() {
      tag.fadeIn(400);
    });
  } else {
    tag.fadeOut(400, function() {
      tag.next().fadeIn();
    });
  }

  // Window scrolls up without this if called by anchor!
  return false;
}

function listveilShow(hider) {
  $(hider).fadeOut(400, function() {
    $(hider).next().fadeIn();
  });
  return false;
}

$(document).ready(function() {
  $('span.lineveil').css('display', 'none');
  $('span.lineveil').after('<span>...</span>');
  $('a.lineveil').click(lineveil);
  $('.listveil * li').wrapInner('<span class="listveil"></span>');
  $('span.listveil').hide().before('<a href="#" onclick="listveilShow(this); return false;">...</a>');

  $('.expandable-link').each(function(i, element) {
    var formId = element.dataset.form;
    element.onclick = function() {
      document.getElementById(formId).submit();
    };
  });
});

function shuffle(list) {
  for (var i = list.length - 1; i > 0; i -= 1) {
    var j = Math.floor(Math.random() * (i + 1));
    var tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
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
    scramble($(this).parent().prev()[0]);
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

function getTimeString(nseconds, nseconds_max) {
  var minutes = Math.floor(nseconds / 60);
  var minutes_max = Math.floor(nseconds_max / 60);
  var seconds = nseconds % 60;

  var s = '';
  
  var diff = ('' + minutes_max).length - ('' + minutes).length;
  for (var i = 0; i < diff; ++i) {
    s += '&nbsp;';
  }

  s += minutes + ':'
  if (nseconds % 60 < 10) {
    s += "0";
  }
  s += nseconds % 60;

  return s;
}

function updateTimedown(id, nseconds, nseconds_max) {
  document.getElementById(id).innerHTML = getTimeString(nseconds, nseconds_max);
  nseconds -= 1;
  if (nseconds >= 0) {
    timers[id] = setTimeout("updateTimedown('" + id + "', " + nseconds + ", " + nseconds_max + ")", 1000);
  } else {
    document.getElementById(id).innerHTML = 'Time\'s up!';
  }
}

function onTimedownClick(id, nseconds) {
  if (timers[id] == undefined) {
    updateTimedown(id, nseconds, nseconds);
  } else {
    clearTimeout(timers[id]);
    timers[id] = undefined;
  }
}

function generateTimedown(nseconds, id) {
  document.write('<div id="' + id + '" align="center" style="font-family: monospace; font-size: xx-large; padding: 0.5em;" onClick="onTimedownClick(\'' + id + '\', ' + nseconds + ')">' + getTimeString(nseconds, nseconds) + '</div>');
}

var timers = {};

function raffle(element, list) {
  if (list.length == 0) {
    element.innerHTML = '&iexcl;no mas!';
  } else {
    element.innerHTML = list[list.length - 1];
    list.splice(list.length - 1);
  }
}
