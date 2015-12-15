module model;

import std.csv;
import std.file;
import std.conv;
import std.array;
import std.range;
import std.stdio;
import std.string;
import std.typecons;
import std.algorithm;
import std.exception;
import std.experimental.logger;

class DelegateLogger : Logger
{
    void delegate(string) @trusted dlg;
    this( LogLevel lv ) @safe { super(lv); }
    override void writeLogMsg(ref LogEntry l) { if( dlg ) dlg( l.msg ); }
}

DelegateLogger dlglogger;

static this() { dlglogger = new DelegateLogger( LogLevel.all ); }

struct YandexAdvRecordRaw
{
    dstring advNo;    // Номер объявления
    dstring phraseID; // ID фразы
    dstring phrase;  // Фраза (с минус-словами)
    dstring advID;   // ID объявления
    dstring title;   // Заголовок
    dstring text;    // Текст
    dstring title_len; // Длина заголовка
    dstring text_len;  // Длина текста
    dstring url;     // Ссылка
    dstring region;  // Регион
    dstring rate;     // Ставка
    dstring thematic_rate; // Ставка на тематич. пл.
    dstring contacts; // Контакты
    dstring adv_status; // Статус объявления
    dstring phrase_status; // Статус фразы
    dstring speed_link_title; // Заголовки быстрых ссылок
    dstring speed_link_url; // Адреса быстрых ссылок
    dstring param1; // Параметр 1
    dstring param2; // Параметр 2
    dstring marks; // Метки
    dstring image; // Изображение
    dstring negative_words; // Минус-слова на объявление
}

struct YandexAdvRecord
{
    ulong advNo;    // Номер объявления
    ulong phraseID; // ID фразы
    dstring phrase;  // Фраза (с минус-словами)
    ulong advID;    // ID объявления
    dstring title;   // Заголовок
    dstring text;    // Текст
    //uint title_len; // Длина заголовка 
    //uint text_len;  // Длина текста
    dstring url;     // Ссылка
    dstring region;  // Регион
    float rate;     // Ставка
    float thematic_rate; // Ставка на тематич. пл.
    dstring contacts; // Контакты
    dstring adv_status; // Статус объявления
    dstring phrase_status; // Статус фразы
    dstring speed_link_title; // Заголовки быстрых ссылок
    dstring speed_link_url; // Адреса быстрых ссылок
    dstring param1; // Параметр 1
    dstring param2; // Параметр 2
    dstring marks; // Метки
    dstring image; // Изображение
    dstring negative_words; // Минус-слова на объявление

    this( YandexAdvRecordRaw raw )
    {
        advNo = raw.advNo.to!ulong.ifThrown(0);
        phraseID = raw.phraseID.to!ulong.ifThrown(0);
        phrase = raw.phrase;

        advID = raw.advID.to!ulong;

        title = raw.title;
        text = raw.text;

        dlglogger.infof( raw.title_len.to!uint.ifThrown(0) != title.walkLength,
                "title length mismatch: '%s'(stored) %s(real)",
                raw.title_len, title.length );

        dlglogger.infof( raw.text_len.to!uint.ifThrown(0) != text.length,
                "text length mismatch: '%s'(stored) %s(real)",
                raw.text_len, text.length );

        url = raw.url;
        region = raw.region;

        rate = raw.rate.to!float;
        thematic_rate = raw.thematic_rate.to!float.ifThrown( float.nan );

        contacts = raw.contacts;
        adv_status = raw.adv_status;
        phrase_status = raw.phrase_status;
        speed_link_title = raw.speed_link_title;
        speed_link_url = raw.speed_link_url;
        param1 = raw.param1;
        param2 = raw.param2;
        marks = raw.marks;
        image = raw.image;
        negative_words = raw.negative_words;
    }
}

struct WorkData
{
    dstring phrase;

    static struct Adv
    {
        dstring title;
        dstring text;
        dstring url;
    }

    this( dstring phrase ) { this.phrase = phrase; }

    void appendNegWords( dstring[] list ) { foreach( w; list ) neg_words[w]++; }

    Adv[] data;

    uint[dstring] neg_words;
}

// структура для хранения найденых совпадений
struct PhrasePair
{
    dstring src; // исходная фраза

    // массив слов, образуется из исходной фразы,
    // хранится отдельно для оптимизации, чтобы
    // не разбивать исходную фразу при каждой проверке
    // и не собирать из списка слов исходную фразу
    dstring[] src_words;

    dstring[] matches; // найденные совпадения

    this( dstring src )
    {
        this.src = src;

        // оптимизация: один раз разбиваем
        // исходную строку на слова
        src_words = src.split(" ");
    }

    void test( dstring ln )
    {
        // не добавлять повторы
        if( ln == src ) return;

        // разбить строку на массив слов по пробелам
        auto w = ln.split(" ");
        // если каждое слово из исходной фразы можно найти
        // в списке слов 
        if( src_words.all!(a=>canFind(w,a)) )
            matches ~= ln; // добавить в списко совпадений
    }
}

dstring str2csv( dstring[] list, dchar delim=',', dchar esc='"' )
{
    dstring[] result;
    foreach( value; list )
    {
        auto buf = value.tr([esc],[esc,esc]);
        if( value.canFind(delim) ) buf = esc ~ buf ~ esc;
        result ~= buf;
    }
    return result.join(",");
}

class Model
{
private:

    enum max_title_len = 30;
    enum max_text_len = 38;
    enum bad_url_query = "utm"d;

    dstring[][] src_raw;
    dstring[][] src;

    WorkData[dstring] gad;

    PhrasePair[] ph_pairs;

    string table_name;

    ulong phrase_index, title_index, text_index, url_index;

public:

    void readYTable( string file, ulong skip )
    {
        dlglogger.infof( "read '%s' file, skip %d first lines", file, skip );
        table_name = file;
        src_raw = [];
        foreach( rec; csvReader!dstring(readText(file)) )
            src_raw ~= rec.array;
        setSkip( skip );
    }
    
    string basename="", fmtpostfix="_y2g_tbl%d.csv";

    void setSkip( ulong skip )
    {
        src = src_raw[skip..$];
    }

    void setIndexes( ulong phrase, ulong title, ulong text, ulong url )
    {
        dlglogger.infof( "set columns: %d %d %d %d", phrase, title, text, url );
        phrase_index = phrase;
        title_index = title;
        text_index = text;
        url_index = url;
    }

    dstring[] getSourceLine( ulong k=0 )
    {
        return [ src[k][phrase_index],
                 src[k][title_index],
                 src[k][text_index],
                 src[k][url_index] ];
    }

    void writeGTables()
    {
        proc();

        if( basename == "" )
            basename = table_name[0..$-4];

        auto tbl = getGTablesNames();

        {
            auto f1 = File( tbl[0], "w" ); scope(exit) f1.close();
            writeKeyWordsWithNegWords( f1 );
        }

        {
            auto f2 = File( tbl[1], "w" ); scope(exit) f2.close();
            writeKeyWordsWithAdv( f2 );
        }

        {
            auto f3 = File( tbl[2], "w" ); scope(exit) f3.close();
            writeKeyWordsMatches( f3 );
        }
    }

    string[] getGTablesNames()
    {
        return [
            format( basename ~ fmtpostfix, 1 ),
            format( basename ~ fmtpostfix, 2 ),
            format( basename ~ fmtpostfix, 3 ),
        ];
    }

protected:

    void proc()
    {
        gadFill();
        phPairsFill();
    }

    void gadFill()
    {
        foreach( rec; src )
        {
            auto r = splitWords( rec[phrase_index] );
            auto kw = r[0].join(" ");
            auto nw = r[1];

            if( kw !in gad )
                gad[kw] = WorkData(kw);

            gad[kw].appendNegWords( nw );
            gad[kw].data ~= WorkData.Adv( rec[title_index],
                                          rec[text_index],
                                          rec[url_index] );
        }
    }

    auto splitWords( dstring phrase )
    {
        dstring[] kw, nw;

        foreach( w; phrase.split(" "d) )
        {
            if( w[0] == '+' ) kw ~= w[1..$];
            else if( w[0] == '-' ) nw ~= w[1..$];
            else kw ~= w;
        }

        return tuple( kw, nw );
    }

    void phPairsFill()
    {
        foreach( ph; gad.keys )
        {
            auto buf = PhrasePair( ph );
            foreach( nph; gad.keys )
                buf.test( nph );
            ph_pairs ~= buf;
        }
    }

    void writeKeyWordsWithNegWords( File f )
    {
        foreach( kw, item; gad )
            foreach( nw; item.neg_words.keys() )
                f.writeln( str2csv( [kw, nw] ) );
    }

    void writeKeyWordsWithAdv( File f )
    {
        foreach( kw, item; gad )
            foreach( adv; item.data )
                f.writeln( str2csv( [kw] ~ procTitle( adv.title ) ~
                                           procText( adv.text ) ~
                                           procUrl( adv.url ) ) );
    }

    void writeKeyWordsMatches( File f )
    {
        // проходим по массиву результатов
        foreach( phrase; ph_pairs )
        {
            // проходим по списку совпадений
            foreach( m; phrase.matches )
                f.writeln( str2csv( [ phrase.src, m ] ) ); // выводим на экран через запятую
        }
    }

    dstring[] testLength( dstring v, ulong size )
    {
        return [ format( "%d"d, v.walkLength ),
                 v.walkLength > size ? "!!!"d : ""d ];
    }

    dstring[] procTitle( dstring orig )
    { return [ orig ] ~ testLength( orig, max_title_len ); }

    dstring[] procText( dstring orig )
    {
        auto ep = orig.split("!");
        if( ep.length > 2 ) ep = [ ep[0..$-1].join("."), ep[$-1] ];
        assert( ep.length <= 2 );
        auto w = ep.join("!").split(" ");

        size_t p = 1;
        size_t sum = 0;

        while( p < w.length && w[0..p+1].join(" "d).walkLength < max_text_len )
            p++;

        auto p1 = w[0..p].join(" "d);
        auto p2 = w[p..$].join(" "d);
        return [ p1 ] ~ testLength( p1, max_text_len ) ~
               [ p2 ] ~ testLength( p2, max_text_len );
    }

    dstring procUrl( dstring orig )
    {
        auto pq = orig.split("?");
        auto path = pq[0];
        if( pq.length > 1 )
        {
            auto q = pq[1].split("&").filter!(a=>!a.startsWith(bad_url_query)).array;
            if( q.length ) path ~= "?" ~ q.join("&");
        }
        return path;
    }
}
