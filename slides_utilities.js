function autosize(id) {
  var element = document.getElementById(id);
  element.width = element.contentWindow.document.body.scrollWidth;
  element.height = element.contentWindow.document.body.scrollHeight;
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

var currentSlide = null;
var onDeckSlide = null;

$(document).ready(function() {
  var slides = $('.gray-slide')
  currentSlide = slides.first();
  if (slides.size() > 1) {
    onDeckSlide = slides[1];
  }
  document.addEventListener('animationend', onAnimationEnd);
  currentSlide.addClass('gray-slide-in-lr');
});

$(document).keydown(function(e) {
  var fadeTime = 1000;
  switch (e.which) {
    case 37:
      var prevs = currentSlide.prevAll('.gray-slide');
      if (prevs.length > 0) {
        currentSlide.removeClass('gray-slide-in-lr gray-slide-in-rl');
        currentSlide.addClass('gray-slide-out-rl');
        currentSlide = prevs.first();
        if (prevs.size() > 1) {
          onDeckSlide = prevs[1];
        } else {
          onDeckSlide = null;
        }
        currentSlide.removeClass('gray-slide-out-lr gray-slide-out-rl');
        currentSlide.addClass('gray-slide-in-rl');
      }
      break;
    case 39:
      var nexts = currentSlide.nextAll('.gray-slide');
      if (nexts.length > 0) {
        currentSlide.removeClass('gray-slide-in-lr gray-slide-in-rl');
        currentSlide.addClass('gray-slide-out-lr');
        currentSlide = nexts.first();
        if (nexts.size() > 1) {
          onDeckSlide = nexts[1];
        } else {
          onDeckSlide = null;
        }
        currentSlide.removeClass('gray-slide-out-lr gray-slide-out-rl');
        currentSlide.addClass('gray-slide-in-lr');
      }
      break;
  }
});

var mupFrames = [];

function onShow(slide) {
  frames = $(slide).find('.madeup-frame');
  frames.each(function(i, frame) {
    loadMadeupFrame(frame);
  });
}

function loadMadeupFrame(frame) {
  var id = frame.name.replace(/mup-frame-/, '');

  // See if frame is already loaded.
  var iFrame = null;
  for (var i = 0; iFrame == null && i < mupFrames.length; ++i) {
    if (mupFrames[i].id == id) {
      iFrame = i;
    }
  }

  // If not loaded, submit the form.
  if (iFrame == null) { 
    if (mupFrames.length >= maxMupFrames) {
      // Sort most recent to least recent.
      mupFrames.sort(function(a, b) {
        if (a.viewed_at > b.viewed_at) {
          return -1;
        } else if (a.viewed_at < b.viewed_at) {
          return 1;
        } else {
          return 0;
        }
      });

      for (var i = maxMupFrames - 1; i < mupFrames.length; ++i) {
        document.getElementById('mup-frame-' + id).src = 'about:blank';
      }
      mupFrames.length = maxMupFrames - 1;
    }

    document.getElementById(frame.name.replace(/^mup-frame/, 'mup-form')).submit();
    mupFrames.push({id: id, viewed_at: Date.now()});
  }
  
  // Otherwise, just freshen its timestamp.
  else {
    mupFrames[iFrame].viewed_at = Date.now();
  }
}

function onDeck(slide) {
  onShow(slide);
}

function onHide(slide) {
}

function onAnimationEnd() {
  // on deck
  if (onDeckSlide != null) {
    onDeck(onDeckSlide);
  }
}
