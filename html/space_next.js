function getKey(event) {
  var keycode;
  var keychar;

  if(window.event) keycode = window.event.keyCode;
  else if(event) keycode = event.which;
  else return false;

  keychar = String.fromCharCode(keycode);

  if(keychar == " ") {
    var next_link = document.getElementById('nav-next');
    if(next_link) {
      location.href = next_link.href;
    }
    return false;
  } else if (keychar == "\b") {
    var prev_link = document.getElementById('nav-prev');
    if(prev_link) {
      location.href = prev_link.href;
    }
    return false;
  }

  return true;
}

document.onkeypress = getKey;


// This was just a silly hack for the 'Jewels in the Core' lightning talk

function d2 (num) {
  var num = '' + num;

  if(num.length < 2) num = '0' + num;
  return num;
}

function setTime () {
  var currTime = new Date();
  var span = document.getElementById('time24');
  if(!span) return;

  timeStr = d2(currTime.getHours()) + ':' + d2(currTime.getMinutes());
  span.innerHTML = timeStr;

  span = document.getElementById('time12');
  if(!span) return;

  timeStr = d2(currTime.getHours() % 12) + ':' + d2(currTime.getMinutes()) + 
            ':' + d2(currTime.getSeconds()) + ' ';
  if(currTime.getHours() < 12) timeStr = timeStr + 'AM' 
  else  timeStr = timeStr + 'PM' 
  span.innerHTML = timeStr;
}

window.onload = setTime;

