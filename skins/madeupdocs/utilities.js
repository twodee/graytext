function autosize(id) {
  var element = document.getElementById(id);
  element.width = element.contentWindow.document.body.clientWidth;
  element.height = element.contentWindow.document.body.clientHeight;
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

document.addEventListener('DOMContentLoaded', function() {

  // Inject Ace editors on all the code snippets.
  var editors = document.querySelectorAll('.text-editor');
  editors.forEach(function(editor) {
    var editor = ace.edit(editor);
    editor.$blockScrolling = Infinity;
    editor.renderer.$cursorLayer.element.style.display = "none";
    editor.setTheme("ace/theme/iplastic");
    editor.getSession().setMode("ace/mode/madeup");
    editor.setOptions({
      maxLines: 15,
      showPrintMargin: false,
      highlightActiveLine: false,
      highlightGutterLine: false,
      readOnly: true,
      fontSize: 16
    });
    editor.renderer.setScrollMargin(10, 10);
  });

  // Inject Blockly workspaces on all the code snippets.
  var switchers = document.querySelectorAll('.mup-switcher');
  var workspaces = [];
  switchers.forEach(function(switcher) {
    var textEditor = switcher.children[0];
    var blocksEditor = switcher.children[1];

    var workspace = Blockly.inject(blocksEditor, {
      comments: false,
      toolbox: false,
      trashcan: false,
      readOnly: true,
      scrollbars: false,
      zoom: false
    });

    // Fit the container exactly around the blocks.
    var sExpression = blocksEditor.firstElementChild.innerHTML;
    parse(new Peeker(sExpression), workspace);
    var metrics = workspace.getMetrics();
    blocksEditor.style.height = metrics.contentHeight + 'px';
    blocksEditor.style.width = metrics.contentWidth + 'px';
    Blockly.svgResize(workspace);

    blocksEditor.style.display = 'none';

    workspaces.push(workspace);
  });

  document.getElementById('to-text').onclick = function() {
    var switchers = document.querySelectorAll('.mup-switcher');
    switchers.forEach(function(switcher) {
      var textEditor = switcher.children[0];
      var blocksEditor = switcher.children[1];
      textEditor.style.display = 'block';
      blocksEditor.style.display = 'none';
    });
    return false;
  };

  document.getElementById('to-blocks').onclick = function() {
    var switchers = document.querySelectorAll('.mup-switcher');
    switchers.forEach(function(switcher) {
      var textEditor = switcher.children[0];
      var blocksEditor= switcher.children[1];
      textEditor.style.display = 'none';
      blocksEditor.style.display = 'block';
      workspaces.forEach(function(workspace) {
        Blockly.svgResize(workspace);
      });
    });
    return false;
  };
});

// window.addEventListener('resize', function() {
  // workspaces.forEach(function(workspace) {
    // console.log("resize");
    // Blockly.svgResize(workspace);
  // });
// });
