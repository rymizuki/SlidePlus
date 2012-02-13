var app = {
};

// jQueryPlugin
(function($,undefined){
    // TODO 結構複雑なコトしているので名前空間をどうにかすべし
    $.fn.navigator = function(){
        var uri = $.url(location.href);
        var path = uri.attr('path');

        var $my = $(this);
        var $clicked;
        if (path==='/')
            $my.filter("[href='/']").addClass('here');
        else {
            $my.each(function(){
                var $a = $(this);
                if($a.attr('href').match(path+'$')) {
                    $a.addClass('here');
                    $clicked = $a;
                } else
                    $a.removeClass('here');
            });
        }

        return $clicked;
    };
})(jQuery);

// イベント登録
(function($){
    $('a.pjax').pjax('#main', {"timeout": 36000});

    var $nav = $('nav#global-nav a');
    $nav.navigator();

    $('#main')
        .bind('pjax:start', function(){})
        .bind('pjax:end', function(){ $nav.navigator(); });

    $("form.uniForm").uniform();
}(jQuery));
