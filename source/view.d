module view;

import std.string;

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
        w.setTitle( "y2g" );
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
                mdl.readYTable( fname, skipLines );
                setInputFileName( fname );
            }

            fcd.destroy();
        });

        obj!Button( "btnsave" ).addOnClicked( (Button b)
        {
            mdl.writeGTables();
            setInfo( "output files: \n" ~ mdl.getGTablesNames().join("\n") );
        });
    }

    void setInputFileName( string fname )
    { obj!Label( "labelinputname" ).setText( fname ); }

    ulong skipLines() @property
    { return cast(ulong)(obj!Adjustment("adjskiplines").getValue); }

    void setInfo( string info ) @trusted
    {
        auto ri = obj!TextBuffer( "bufresultinfo" );
        ri.setText( ri.getText() ~ "\n" ~ info );
    }
}

void runView( string[] args, Model mdl )
{
    Main.init( args );
    new UI( mdl );
    Main.run();
}
