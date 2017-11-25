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
	public class FileStack : Stack
	{
		public GLib.File folder { get; construct set; }
		
		public bool is_read_only { get; private set; }
		
		public bool is_unreadable { get; private set; }
		
		public FileStack (GLib.File folder)
		{
			GLib.Object (folder : folder);
		}
		
		construct
		{
			notify["folder"].connect (update_elements);
			
			element_compare_func = (CompareDataFunc) compare_file_elements;
		}
		
		~FileStack ()
		{
			notify["folder"].disconnect (update_elements);
		}
		
		void update_elements ()
		{
			if (folder == null || !folder.query_exists ())
				return;
			
#if BENCHMARK
			var start = new DateTime.now_local ();
#endif
			try {
				FileInfo info;
				info = folder.query_info ("standard::name,access::can-write,access::can-read",
					GLib.FileQueryInfoFlags.NONE, null);
				is_read_only = !info.get_attribute_boolean ("access::can-write");
				is_unreadable = !info.get_attribute_boolean ("access::can-read");
				
				var enumerator = folder.enumerate_children ("standard::name,standard::icon,standard::type,"
					+ "standard::is-hidden,thumbnail::path,metadata::custom-icon,"
					+ "access::can-write,standard::is-symlink,access::can-read,access::can-execute",
					GLib.FileQueryInfoFlags.NONE);
				
				while ((info = enumerator.next_file ()) != null) {
					if (info.get_is_hidden ())
						continue;
					
					var file = folder.get_child (info.get_name ());
					var element = new FileStackElement (file);
					element.update_from_fileinfo (info);
					add_element (element);
				}
			} catch (GLib.Error e) {
				debug ("update_elements - %s: %s", e.domain.to_string (), e.message);
			}
			
#if BENCHMARK
			var end = new DateTime.now_local ();
			var diff = end.difference (start) / 1000.0;
			if (diff > 5.0)
				message ("loading time - %f ms", diff);
#endif
			layout ();
		}
		
		protected override bool on_clicked (Gdk.EventButton event, StackElement? element)
		{
			// right click opens parent directory
			if (event.button == Gdk.BUTTON_SECONDARY) {
				if (folder != null)
					folder = folder.get_parent ();
				return true;
			}
			
			if (element == null)
				return true;
			
			unowned FileStackElement? fe = (element as FileStackElement);
			if (fe == null || fe.is_unreadable)
				return true;
			
			unowned File owned_file = fe.owned_file;
			
			// middle click opens the directory in the file manager
			if (event.button == Gdk.BUTTON_MIDDLE) {
				System.get_default ().open (owned_file);
				return false;
			}
			
			if (owned_file.query_file_type (FileQueryInfoFlags.NONE, null) == GLib.FileType.DIRECTORY) {
				folder = owned_file.dup ();
				return true;
			}
			
			if (owned_file.get_basename ().has_suffix (".desktop"))
				System.get_default ().launch (owned_file);
			//else if (fe.is_executable)
			//	DockServices.System.Execute (owned_file.Path);
			else
				System.get_default ().open (owned_file);
			
			return false;
		}
		
		static int compare_file_elements (FileStackElement left, FileStackElement right)
		{
			if (left.is_directory == right.is_directory)
				return left.text.ascii_casecmp (right.text);
			
			if (left.is_directory)
				return -1;
			else
				return 1;
		}
	}
}
