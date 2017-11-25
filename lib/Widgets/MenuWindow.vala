//
//  Copyright (C) 2012 Rico Tzschichholz
//
//  This file is part of Plank.
//
//  Plank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Plank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank
{
	public class MenuWindow : Gtk.Window
	{
		public MenuWindow ()
		{
			GLib.Object (type: Gtk.WindowType.TOPLEVEL, type_hint: Gdk.WindowTypeHint.MENU);
		}
		
		construct
		{
			//app_paintable = true;
			decorated = false;
			resizable = false;
			
			set_accept_focus (true);
			set_modal (true);
			can_focus = true;
			skip_pager_hint = true;
			skip_taskbar_hint = true;
			set_redraw_on_allocate (true);
			
			unowned Gtk.StyleContext context = get_style_context ();
			context.add_class (Gtk.STYLE_CLASS_MENU);
			
			add_events (Gdk.EventMask.FOCUS_CHANGE_MASK);
		}
		
		~MenuWindow ()
		{
			print ("menu gone\n");
		}
		
		public override bool focus_out_event (Gdk.EventFocus event)
		{
			hide ();
			remove (get_child ());
			
			return true;
		}
	}
}
