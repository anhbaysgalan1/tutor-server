//= require jquery
//= require jquery_ujs
//= require jquery.datetimepicker
//= require jquery-ui-1.11.4.custom.min
//= require bootstrap-sprockets

//=============== Date Time Picker ============//
$(document).ready(function() {
  $('.datepicker').datetimepicker({
  });
});

//============= Courses =================//
$(document).ready(function() {
  //=========== Course teacher auto complete ==============//
  $('#course_teacher').autocomplete({
    minLength: 2,
    select: function(event_, ui) {
      $('#course_teacher').val(ui.item.label);
      var hidden = $('<input type="hidden" name="teacher_ids[]"/>');
      hidden.val(ui.item.value);
      $('#course_teacher').after(hidden);
      $('#assign-teachers-form').submit();
      return false;
    },
    source: function(request, response, url) {
      var searchParam = request.term;
      $.ajax({
        url: '/admin/users.json',
        data: {search_term: searchParam},
        type: 'GET',
        beforeSend: function(xhr) {
          xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
        },
        success: function(data) {
          response($.map(data.items, function(item) {
            return {
              label: item.name + ' (' + item.username + ')',
              value: item.entity_user_id
            };
          }));
        }
      });
    }
  });

  //========== Course tab selection =============//
  var tab = window.location.hash;
  if (tab) {
    $('a[href="' + tab + '"]').click();
  }
});

// === Admin/Jobs === //
$(function(){
  $(document).on('click', '.filter_job_status', function(e) {
    var desiredStatus = this.href.replace(/^\S+#/, ''),
        $showRows = $('.' + desiredStatus),
        $hideRows = $('#jobs tbody tr').not('.' + desiredStatus),
        $plainTxt = $('<span/>').text(desiredStatus),
        $prevSpan = $($(this).siblings('span')[0]),
        prevSpanTxt = $prevSpan.text(),
        $linkedTxt = $('<a/>').addClass('filter_job_status')
                              .text(prevSpanTxt)
                              .attr('href', '#' + prevSpanTxt);

    if (desiredStatus === 'all') {
      $showRows = $('#jobs tbody tr');
      $hideRows = $();
    } else if (desiredStatus === 'incomplete') {
      $showRows = $('#jobs tbody tr').not('.completed');
      $hideRows = $('.completed');
    }

    $prevSpan.replaceWith($linkedTxt);
    $(this).replaceWith($plainTxt);
    $showRows.show();
    $hideRows.hide();
  }).on('keyup', '#filter_id', function(e) {
    var span = $(this).siblings('span')[0];

    if ($(this).val() !== '' && span === undefined) {
      var placeholder = $(this).attr('placeholder'),
          $label = $('<span/>').text(placeholder);

      $('#search_by_id').prepend($label);
    }

    if ($(this).val() === '') {
      $(span).remove();
    }

    $('#jobs tbody tr').hide();
    $("#jobs tbody tr:contains('" + $(this).val() + "')").show();
  });
});
