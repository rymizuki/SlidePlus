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

$(function(){
    // = websocket =
    var uri = $.url(location.href); // TODO navigatorと重複している処理
    var path = uri.attr('path');

    if (!path.match(/controller/)) return;

    var rid = path.split('/')[3];
    var ws  = "ws://"+location.host+"/websocket/"+rid;

    // TODO 共通化
    var socket;
    if      (typeof WebSocket != 'undefined')    socket = new WebSocket(ws);
    else if (typeof MozWebSocket != 'undefined') socket = new MozWebSocket(ws);
    else {
        alert('WebSocket非対応です');
        return false;
    }
    var connection_interval = setInterval(function(){socket.send('ping')}, 20000);


    var make_key = function(len, source){
        var result = "", source_length = source.length;
        for (var i=0; i < len; i++) result += source.charAt(Math.floor(Math.random() * source_length));
        return result;
    }

    var $status = $('#status'), key = "";
    socket.onopen = function(){
        $status.text('slideとの通信を開始します');
        key = make_key(5, "0123456789");
        socket.send(JSON.stringify({mode:'connect', key:key}));
        $status.text('通信を特定するため、次の文字列をスライド側で入力してください:'+key);
    };

    var next = JSON.stringify({mode: 'next', key:key});
    var back = JSON.stringify({mode: 'back', key:key});

    socket.onmessage = function (msg) {
        var res = JSON.parse(msg.data);
        switch(res.mode) {
            case 'connection-res':
                if(res.response == 'ok') {
                    $status.text('スライドとの通信を開始します');
                    next = JSON.stringify({mode: 'next', key:key});
                    back = JSON.stringify({mode: 'back', key:key});
                }
                else $status.text('スライドとの通信に失敗しました');
                break;
            case 'next':
            case 'back': $status.text(res.mode+'の処理を送信しました'); break;
        }
    }

    socket.onclose = function(){
        $status.text("通信が切断されました");
        key = "";
    }

    $('#slide-controller #next').click(function(){ socket.send(next); });
    $('#slide-controller #back').click(function(){ socket.send(back); });
});
