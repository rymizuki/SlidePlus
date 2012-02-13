// TODO slideshow object
var slideshow = {
    "config" : {},
    "slides" : [],
    "paths"  : [],
};
var slideshow._init = function () {
    this.config = {
        "show_area"     : 'section',
        "slide_holder"  : 'article',
    };
    var config = this.config;

    var $section  = $(config.show_area);
    var $to_slide = $section.children(':not('+config.slide_holder')');
    var contents  = $section.children(config.slide_holder);

    var $slides = [$top_slide];
    for (var cnt=1; cnt <= contents.length; cnt++) {
        $slides[cnt] = $(contents[cnt-1]).hide();
    }

    this.slides = $slides[cnt];
};
var slideshow.getPage = function(path){
    var paths = path.split('/');
    var page = paths[4];
    this.paths = paths.splice(4,1);
    return page;
};
var slideshow._setPushState = function(page) {
    var paths = this.paths;
    var make_path = paths.join('/')+'/'+page;
    window.history.pushState({"page":page}, null, make_path);
};
var slideshow.changePage = function(page) {
    var $slides = this.slides;
    if (page >= $slides.length) return;
    if (!page || page < 0) page = 0;
    // TODO もっといいやり方あるきがする
    $(this.config.show_area).children().hide();
    $slides[page].show();

    this._setPushState(page);
};
var slideshow.backPage = function(path) {
    var curr_page = this.getPage(path);
    this.changePage(--curr_page);
};
var slideshow.nextPage = function(path) {
    var curr_page = this.getPage(path);
    this.changePage(++curr_page);
};
var slideshow.popPage = function(path) {
    // TODO hitstory.stateが取得できない。
    alert('ブラウザバックできないのよん');
};

$(function(){

    // コンテンツを書き換える対象
    var $section = $('section');
    var $top_slide = $section.children(':not(article)');
    var contents = $section.children("article");

    // 初期化
    var $slides = [$top_slide];
    for (var cnt=1; cnt <= contents.length; cnt++) {
        $slides[cnt] = $(contents[cnt-1]).hide();
    }

    // urlのpathからpage番号を取得
    var paths;
    var getPage = function(path) {
        paths = path.split('/');
        var page = paths[4];
        paths.splice(4,1); // page番号を切り捨て
        return page;
    };

    // pushStateにページ番号入れる
    var setPushState = function(page) {
        var make_path = paths.join('/')+'/'+page;
        var state = {"page":page};
        window.history.pushState(state, document.title, make_path);
    }

    // page番号を見てスライドを更新
    var changePage = function(page){
        if (page >= $slides.length) return;
        if (!page || page < 0) page = 0;
        $section.children().hide();
        $slides[page].show();

        setPushState(page);
    };
    // 前のページ
    var backPage = function(path) {
        var curr_page = getPage(path);
        changePage(--curr_page);
    };
    // 次のページ
    var nextPage = function(path) {
        var curr_page = getPage(path);
        changePage(++curr_page);
    };
    // 進む/戻る が押された時のページ
    var popPage = function(e, path) {
        // TODO history.stateがうまく動作していない様子。一旦保留
        var curr_page = getPage(path);
        changePage(curr_page);
    };

    // controller
    var curr_page = getPage(location.pathname);
    changePage(curr_page);

    $('#controller > #next').click(function(e){nextPage(location.pathname)});
    var $w = $(window);
    $w.bind('popstate', function(e){ popPage(e, location.pathname); });
    $w.bind('keydown', function(e){
        switch(e.which) {
            case 78:
            case 13:
            case 39: nextPage(location.pathname);break;
            case 66:
            case 80:
            case 37: backPage(location.pathname);break;
        }
    });
});
