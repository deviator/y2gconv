module view;

import std.stdio;
import std.string;
import std.conv;

import gtk.Widget;
import gtk.Main;
import gtk.Window;
import gtk.Label;
import gtk.Builder;
import gtk.Button;
import gtk.TextBuffer;
import gtk.Adjustment;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.ListStore;
import gtk.TreeIter;
import gobject.Value;

import model;

enum UI_XML = import( "ui.glade" );

class ViewException : Exception
{ this( string msg ) @safe pure nothrow { super( msg ); } }

class UI
{
    Builder builder;
    Model mdl;

    this( Model mdl )
    {
        builder = new Builder;
        if( !builder.addFromString( UI_XML ) )
            throw new ViewException( "cannot create ui" );

        this.mdl = mdl;
        dlglogger.dlg = &setInfo;

        prepare();
    }

    auto obj(T)( string name )
    {
        auto ret = cast(T)builder.getObject( name );
        if( ret is null )
            throw new ViewException( format( "no %s '%s' element", typeid(T).name, name ) );
        return ret;
    }

    void prepare()
    {
        auto w = obj!Window( "mwindow" );
        w.setTitle( "y2g conv" );
        w.addOnHide( (Widget aux){ Main.quit(); } );
        w.showAll();

        obj!Button( "btnopen" ).addOnClicked( (Button b)
        {
            auto fcd = new FileChooserDialog( "Choise table", null, FileChooserAction.OPEN );

            {
                auto f = new FileFilter;
                f.setName( "CSV" );
                f.addPattern( "*.csv" );
                fcd.addFilter( f );
            }

            if( fcd.run() == ResponseType.OK )
            {
                auto fname = fcd.getFilename();

                try mdl.readYTable( fname, skipLines );
                catch(Throwable e )
                    setInfo( "ERROR WHILE READING FILE: " ~ e.msg );

                setInputFileName( fname );
                updateColumnIndexes();
            }

            fcd.destroy();
        });

        obj!Button( "btnsave" ).addOnClicked( (Button b)
        {
            try mdl.writeGTables();
            catch(Throwable e) setInfo( "ERROR WHILE SAVING FILES: " ~ e.msg );
            setInfo( "output files: \n" ~ mdl.getGTablesNames().join("\n") );
        });

        void colIndexChange( Adjustment ) { updateColumnIndexes(); }
        void adjOnChange( string name )
        { obj!Adjustment( name ).addOnValueChanged( &colIndexChange ); }

        adjOnChange( "adjphraseindex" );
        adjOnChange( "adjtitleindex" );
        adjOnChange( "adjtextindex" );
        adjOnChange( "adjurlindex" );

        obj!Adjustment( "adjskiplines" ).addOnValueChanged( (Adjustment a)
        {
            mdl.setSkip( cast(ulong)(a.getValue()) );
            updateViewColumnValues();
        });
    }

    void setInputFileName( string fname )
    { obj!Label( "labelinputfile" ).setText( fname ); }

    ulong skipLines() @property
    { return cast(ulong)(obj!Adjustment("adjskiplines").getValue); }

    void setInfo( string info ) @trusted
    {
        auto ri = obj!TextBuffer( "bufresultinfo" );
        ri.setText( ri.getText() ~ "\n" ~ info );
    }

    void updateColumnIndexes()
    {
        ulong adjvalue( string name )
        { return cast(ulong)( obj!Adjustment( name ).getValue() ); }

        mdl.setIndexes( adjvalue( "adjphraseindex" ),
                        adjvalue( "adjtitleindex" ),
                        adjvalue( "adjtextindex" ),
                        adjvalue( "adjurlindex" ) );

        updateViewColumnValues();
    }

    void updateViewColumnValues()
    {
        auto values = mdl.getSourceLine(0);

        auto rl = obj!ListStore( "lsfirstline" );

        rl.clear();

        rl.setValuesv( rl.createIter(), [0,1],
                [ new Value( "фраза" ), new Value( values[0].to!string ) ] );
        rl.setValuesv( rl.createIter(), [0,1],
                [ new Value( "заголовок" ), new Value( values[1].to!string ) ] );
        rl.setValuesv( rl.createIter(), [0,1],
                [ new Value( "текст" ), new Value( values[2].to!string ) ] );
        rl.setValuesv( rl.createIter(), [0,1],
                [ new Value( "ссылка" ), new Value( values[3].to!string ) ] );
    }
}

void runView( string[] args, Model mdl )
{
    Main.init( args );
    new UI( mdl );
    Main.run();
}
