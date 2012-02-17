(function($){
    var SlideShow = function(config){
        this.paths  = [];
        this.page   = 0;
        this.section = $(config.section_tag);
        this.title   = $(config.title_tag);
        this.contents= $(config.content_tag);

        var contents = this.contents;
        var pages    = [this.title];
        for (var cnt=1; cnt <= contents.length; cnt++) {
            pages[cnt] = $(contents[cnt-1]).hide();
        }

        this.pages = pages;
    };
    SlideShow.prototype.getPage = function(path) {
        var paths = path.split('/');
        var page  = paths[4];
        paths.splice(4,1);
        this.paths = paths;
        this.page  = page;
        return page;
    };
    SlideShow.prototype._setPushState = function() {
        var page = this.page;
        var push_path = this.paths.join('/')+'/'+page;
        window.history.pushState({curr_page:page}, document.title, push_path);
    };
    SlideShow.prototype.changePage = function(page) {
        var pages = this.pages;
        if (page >= pages.length) return;
        if (!page || page < 0) page = 0;
        this.section.children().hide();
        pages[page].show();

        this.page = page;
        this._setPushState();
    };
    SlideShow.prototype.backPage = function(path) {
        var curr_page = this.getPage(path);
        this.changePage(--curr_page);
    };
    SlideShow.prototype.nextPage = function(path) {
        var curr_page = this.getPage(path);
        this.changePage(++curr_page);
    };

    $.slideShow = function(config, pathname){
        var config = $.extend({
            section_tag: 'section',
            title_tag  : ':not(article)',
            content_tag: 'article',
        }, config);

        if (pathname === undefined) pathname = location.pathname;

        var sl = new SlideShow(config);
        var curr_page = sl.getPage(pathname);
        sl.changePage(curr_page);

        return sl;
    };
}(jQuery));
