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
	public abstract class StackElement : GLib.Object
	{
		public const int ICONSIZE = 64;
		public const int PADDING = 4;
		public const int LINEWIDTH = 2;
		public const int FONTSIZE = 14;
		public const int MAX_CAPTION_LINE_COUNT = 3;
		
		public const int TEXT_WIDTH = 2 * ICONSIZE;
		public const int DEFAULT_WIDTH = 2 * (ICONSIZE + PADDING + LINEWIDTH);
		public const int DEFAULT_HEIGHT = 2 * (PADDING + LINEWIDTH) + ICONSIZE + PADDING + FONTSIZE;
		
		public signal void size_changed ();
		//public signal void needs_redraw ();
		
		public Stack? owner { get; set; default = null; }
		
		public Gdk.Rectangle Area { get; private set; }
		
		protected Gdk.Pixbuf? IconPixbuf { get; set; default = null; }
		protected string Icon { get; set; }
		protected bool FitIcon { get; set; default = false; }
		
		public string text { get; protected set; }
		public string tooltip {	get; private set; }
		
		public bool is_realized { get; set; default = false; }
		public bool show_caption { get; private set; default = true; }
		
		Pango.Layout label_layout;
		
		construct
		{
			label_layout = new Pango.Layout (Gdk.pango_context_get ());
			label_layout.set_wrap (Pango.WrapMode.WORD_CHAR);
			label_layout.set_alignment (Pango.Alignment.CENTER);
			
			var style = new Gtk.Style ();
			weak Pango.FontDescription font_description = style.font_desc;
			font_description.set_absolute_size ((int) (FONTSIZE * Pango.SCALE));
			label_layout.set_width ((int) (TEXT_WIDTH * Pango.SCALE));
			label_layout.set_font_description (font_description);
		}

		public void draw_label (Cairo.Context cr, double x, double y)
		{
			unowned Gtk.Widget? widget = (owner as Gtk.Widget);
			if (widget == null)
				return;
			
			unowned Gtk.StyleContext context = widget.get_style_context ();
			cr.save ();
			//context.save ();
			
			//context.set_state (widget.get_state_flags () | Gtk.StateFlags.SELECTED);
			context.render_layout (cr, x, y, label_layout);
			
			//context.restore ();
			cr.restore ();
		}
		
		public void move_to (int x, int y)
		{
			if (x == Area.x && y == Area.y)
				return;
			
			Area = { x, y, Area.width, Area.height };
			is_realized = false;
		}
		
		public void reset ()
		{
			IconPixbuf = null;
			
			update ();
		}
		
		public abstract bool draw (Cairo.Context cr);
		
		public void update ()
		{
			int old_height = Area.height, old_width = Area.width;
			
			int label_height;
			update_label_height (out label_height);
			
			int height = 2 * (PADDING + LINEWIDTH) + ICONSIZE + (show_caption && label_height > 0 ? PADDING + label_height : 0);
			int width = DEFAULT_WIDTH;
			Area = { Area.x, Area.y, width, height };
			
			if (width != old_width || height != old_height) {
				is_realized = false;
				size_changed ();
			}
			
			//print ("%s %i\n", text, ++updated);
			//print ("w: %i, h: %i, l: %i\n", Width, Height, label_height);
		}
		
		void update_label_height (out int label_height)
		{
			if (!show_caption || text == null || text.length == 0) {
				label_layout.set_text ("", 0);
				label_height = 0;
				tooltip = "";
				return;
			}
			
			bool needs_tooltip = false;
			string caption;
			int caption_truncate_offset = 0;
			
			label_layout.set_text (text, text.length);
			
			if (label_layout.get_line_count () > MAX_CAPTION_LINE_COUNT) {
				needs_tooltip = true;
				unowned Pango.LayoutLine line = label_layout.get_line_readonly (MAX_CAPTION_LINE_COUNT);
				caption_truncate_offset = line.start_index;
				if (needs_tooltip && caption_truncate_offset > 2 && text.length > caption_truncate_offset + 1)
					caption = text.substring (0, caption_truncate_offset - 2).strip () + "...";
				else
					caption = text;
				label_layout.set_text (caption, caption.length);
			}
			
			Pango.Rectangle logical, ink;
			label_layout.get_pixel_extents (out ink, out logical);
			label_height = logical.height;
			
			tooltip = (needs_tooltip && show_caption ? text : "");
		}
	}
}
