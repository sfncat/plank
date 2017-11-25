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
	public class FileStackElement : StackElement
	{
		public GLib.File owned_file { get; construct; }
		
		public bool is_directory { get; private set; }
		public bool is_executable { get; private set; }
		public bool is_read_only { get; private set; }
		public bool is_unreadable { get; private set; }
		public bool is_symbolic { get; private set; }
		
		public FileStackElement (GLib.File file)
		{
			GLib.Object (owned_file : file);
		}
		
		void update_info ()
		{
			try {
				var info = owned_file.query_info ("standard::name,standard::icon,standard::type,thumbnail::path,"
					+ "metadata::custom-icon,access::can-write,standard::is-symlink,access::can-read,"
					+ "access::can-execute",
					GLib.FileQueryInfoFlags.NONE, null);
				
				update_from_fileinfo (info);
			} catch (GLib.Error e) {
				debug ("update_info - %s: %s", e.domain.to_string (), e.message);
				Icon = "gtk-file";
				text = owned_file.get_basename ();
				
				update ();
			}
		}
		
		public void update_from_fileinfo (FileInfo info)
		{
			is_directory = (info.get_file_type () == GLib.FileType.DIRECTORY);
			is_symbolic = info.get_attribute_boolean ("standard::is-symlink");
			is_read_only = !info.get_attribute_boolean ("access::can-write");
			is_unreadable = !info.get_attribute_boolean ("access::can-read");
			is_executable = !info.get_attribute_boolean ("access::can-execute");
			
			FitIcon = false;
			
			string? icon = null;
			string? label = null;
			
			if (info.get_name ().has_suffix (".desktop")) {
				var app = new DesktopAppInfo.from_filename (owned_file.get_path ());
				icon = DrawingService.get_icon_from_gicon (app.get_icon ());
				label = app.get_name ();
			} else if ((icon = info.get_attribute_string ("metadata::custom-icon")) != null) {
				if (!icon.has_prefix ("file://"))
					icon = owned_file.get_uri () + "/" + icon;
			} else if ((icon = info.get_attribute_byte_string ("thumbnail::path")) != null) {
				FitIcon = true;
			} else {
				icon = DrawingService.get_icon_from_gicon (info.get_icon ());
			}
			
			if (icon == null || icon.length == 0)
				icon = "gtk-file";
			
			if (label == null || label.length == 0)
				label = info.get_name ();
			
			Icon = icon;
			text = label;
			
			update ();
		}
		
		public override bool draw (Cairo.Context cr)
		{
			// draw file-icon
			Gdk.Pixbuf icon_pbuf = IconPixbuf;
			bool is_icon_cached = (icon_pbuf != null);
			if (!is_icon_cached) {
				// buffer only IconTheme icons
				string icon_name = Icon;
				if (icon_name.contains ("/")) {
					if (FitIcon)
						icon_pbuf = DrawingService.load_icon (icon_name, (int) (1.66 * ICONSIZE), ICONSIZE);
					else
						icon_pbuf = DrawingService.load_icon (icon_name, ICONSIZE, ICONSIZE);
				} else if ((icon_pbuf = Stack.icon_cache.@get (icon_name)) == null) {
					icon_pbuf = DrawingService.load_icon (icon_name, ICONSIZE, ICONSIZE);
					IconPixbuf = icon_pbuf;
					Stack.icon_cache.@set (icon_name, icon_pbuf);
					is_icon_cached = true;
				}
			}
			Gdk.cairo_set_source_pixbuf (cr, icon_pbuf,
				(Area.width - icon_pbuf.width) / 2,
				(ICONSIZE - icon_pbuf.height) / 2 + PADDING + LINEWIDTH);
			cr.paint ();
			
			// draw symbolic-link emblem
			Gdk.Pixbuf emblem;
			string emblem_icon_name;
			if (is_symbolic) {
				emblem_icon_name = "emblem-symbolic-link";
				if ((emblem = Stack.icon_cache.@get (emblem_icon_name)) == null) {
					emblem = DrawingService.load_icon (emblem_icon_name, ICONSIZE / 3, ICONSIZE / 3);
					Stack.icon_cache.@set (emblem_icon_name, emblem);
				}
				Gdk.cairo_set_source_pixbuf (cr, emblem,
					(Area.width + icon_pbuf.width) / 2 - ICONSIZE / 6,
					PADDING + LINEWIDTH);
				cr.paint ();
			}
			// draw file-permission emblem
			unowned FileStack? parent = (owner as FileStack);
			if (parent != null && !parent.is_read_only && is_read_only) {
				emblem_icon_name = "emblem-readonly";
				if ((emblem = Stack.icon_cache.@get (emblem_icon_name)) == null) {
					emblem = DrawingService.load_icon (emblem_icon_name, ICONSIZE / 3, ICONSIZE / 3);
					Stack.icon_cache.@set (emblem_icon_name, emblem);
				}
				Gdk.cairo_set_source_pixbuf (cr, emblem, 
					(Area.width + icon_pbuf.width) / 2 - ICONSIZE / 6,
					2 * ICONSIZE / 3 + PADDING + LINEWIDTH);
				cr.paint ();
			} else if (parent != null && !parent.is_unreadable && is_unreadable) {
				emblem_icon_name = "emblem-unreadable";
				if ((emblem = Stack.icon_cache.@get (emblem_icon_name)) == null) {
					emblem = DrawingService.load_icon (emblem_icon_name, ICONSIZE / 3, ICONSIZE / 3);
					Stack.icon_cache.@set (emblem_icon_name, emblem);
				}
				Gdk.cairo_set_source_pixbuf (cr, emblem,
					(Area.width + icon_pbuf.width) / 2 - ICONSIZE / 6,
					2 * ICONSIZE / 3 + PADDING + LINEWIDTH);
				cr.paint ();
			}
			
			// draw caption
			if (show_caption)
				draw_label (cr, LINEWIDTH + PADDING, LINEWIDTH + 2 * PADDING + ICONSIZE);
			
			return true;
		}
	}
}

