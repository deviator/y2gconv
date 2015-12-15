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
        advNo = raw.advNo.to!ulong;
        phraseID = raw.phraseID.to!ulong;
        phrase = raw.phrase;

        advID = raw.advID.to!ulong;

        title = raw.title;
        text = raw.text;

        infof( raw.title_len.to!uint.ifThrown(0) != title.walkLength,
                "title length mismatch: '%s'(stored) %s(real)",
                raw.title_len, title.length );

        infof( raw.text_len.to!uint.ifThrown(0) != text.length,
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

class Model
{
private:
    enum max_title_len = 30;
    enum max_text_len = 38;
    enum bad_url_query = "utm"d;

    YandexAdvRecord[] src;

    WorkData[dstring] gad;

    PhrasePair[] ph_pairs;

public:
    void readYTable( string file, ulong skip=10 )
    {
        auto data = csvReader!YandexAdvRecordRaw( readText(file).splitLines[skip..$].join("\n"), ',', '"' );
        src = data.map!(a=>YandexAdvRecord(a)).array;
    }

    void proc()
    {
        gadFill();
        phPairsFill();
    }

    void writeGTables( string basename, string fmt="_y2g_tbl%d.csv" )
    {
        auto f1 = File( format( basename ~ fmt, 1 ), "w" ); scope(exit) f1.close();
        writeKeyWordsWithNegWords( f1 );

        auto f2 = File( format( basename ~ fmt, 2 ), "w" ); scope(exit) f2.close();
        writeKeyWordsWithAdv( f2 );

        auto f3 = File( format( basename ~ fmt, 3 ), "w" ); scope(exit) f3.close();
        writeKeyWordsMatches( f3 );
    }

protected:

    void gadFill()
    {
        foreach( rec; src )
        {
            auto r = splitWords( rec.phrase );
            auto kw = r[0].join(" ");
            auto nw = r[1];

            if( kw !in gad )
                gad[kw] = WorkData(kw);

            gad[kw].appendNegWords( nw );
            gad[kw].data ~= WorkData.Adv( rec.title, rec.text, rec.url );
        }
    }

    auto splitWords( dstring phrase )
    {
        dstring[] kw, nw;

        foreach( w; phrase.split(" "d) )
        {
            if( w[0] == '+' ) kw ~= "!"d ~ w[1..$];
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
                f.writefln( "%(%s,%)", [kw, nw] );
    }

    void writeKeyWordsWithAdv( File f )
    {
        foreach( kw, item; gad )
            foreach( adv; item.data )
                f.writefln( "%(%s,%)", [kw] ~ procTitle( adv.title ) ~
                                              procText( adv.text ) ~
                                              procUrl( adv.url ) );
    }

    void writeKeyWordsMatches( File f )
    {
        // проходим по массиву результатов
        foreach( phrase; ph_pairs )
        {
            // проходим по списку совпадений
            foreach( m; phrase.matches )
                f.writeln( phrase.src, ", ", m ); // выводим на экран через запятую
        }
    }

    dstring[2] procTitle( dstring orig )
    {
        return [ orig, orig.walkLength > max_title_len ? "!!!"d : ""d ];
    }

    dstring[3] procText( dstring orig )
    {
        auto kw = orig.tr("!",".").split(" ");

        size_t p = 0;
        size_t sum = 0;

        while( sum + kw[p].walkLength < max_text_len )
        {
            p++;
            sum += kw[p].walkLength;
        }

        auto p1 = kw[0..p].join(" ");
        auto p2 = kw[p..$].join(" ");
        return [ p1, p2, p2.walkLength > max_text_len ? "!!!"d : ""d ];
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