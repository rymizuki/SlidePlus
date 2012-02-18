(function($){
    var SlideShow = function(){
        this.paths  = [];
        this.page   = 0;
    };
    SlideShow.prototype.init = function(config){
        this.section = $(config.section_tag);
        this.title   = this.section.children(config.title_tag);
        this.contents= $(config.content_tag);

        var contents = this.contents;
        var pages    = [this.title];
        for (var cnt=1; cnt <= contents.length; cnt++) {
            pages[cnt] = $(contents[cnt-1]).hide();
        }

        for(var cnt=0; cnt < pages.length; cnt++) {
            pages[cnt]
                .bind('slide:hide', config.hide)
                .bind('slide:show', config.show);
        }

        this.pages = pages;
    };
    SlideShow.prototype.getPage = function(path) {
        var paths = path.split('/');
        var page  = paths[4];
        paths.splice(4,1);
        this.paths = paths;
        return page;
    };
    SlideShow.prototype._setPushState = function() {
        var page = this.page;
        var push_path = this.paths.join('/')+'/'+page;
        window.history.pushState({curr_page:page}, document.title, push_path);
    };
    SlideShow.prototype.changePage = function(page, handler) {
        var pages = this.pages;

        if (!page) page = 0;
        if ((page >= pages.length) || (page < 0 && handler == 'back')) return;

        var prev_page = this.page;
        if (prev_page === undefined) prev_page = 0;

        pages[prev_page].trigger('slide:hide');
        pages[page].trigger('slide:show');

        this.page = page;
        this._setPushState();
    };
    SlideShow.prototype.backPage = function(path) {
        var curr_page = this.getPage(path);
        this.changePage(--curr_page, 'back');
    };
    SlideShow.prototype.nextPage = function(path) {
        var curr_page = this.getPage(path);
        this.changePage(++curr_page, 'next');
    };

    var sl = new SlideShow();

    $.slideShow = function(config){
        var config = $.extend({
            section_tag: 'section',
            title_tag  : ':not(article)',
            content_tag: 'article',
            hide: function(e){$(this).hide('slow');},
            show: function(e){$(this).show('slow');},
        }, config);


        sl.init(config);

        var pathname = location.pathname;
        var curr_page = sl.getPage(pathname);
        sl.changePage(curr_page);

        return sl;
    };
    $.fn.slideControllerButton = function(config) {
        var config = $.extend({
            mode: '', // next or back
        }, config);

        var $my = this;
        switch(config.mode) {
            case 'next': $my.click(function(){sl.nextPage(location.pathname)}); break;
            case 'back': $my.click(function(){sl.backPage(location.pathname)}); break;
            default: alert('un matched mode.');
        }

        return $my;
    };
    $.fn.slideControllerKeys = function(config) {
        var config = $.extend({
            mode: '', // next or back
            keys: [],
        },config);

        var $my = this;
        var mode = config.mode;
        var keys = config.keys;
        if (mode == 'next') {
            $my.bind('keydown', function(e){
                for (var i=0; i < keys.length; i++) if (e.which == keys[i]) sl.nextPage(location.pathname);
            });
        } else if(mode == 'back') {
            $my.bind('keydown', function(e){
                for (var i=0; i < keys.length; i++) if (e.which == keys[i]) sl.backPage(location.pathname);
            });
        } else {
            alert('unmached mode.');
        }

        return $my;
    };
}(jQuery));
