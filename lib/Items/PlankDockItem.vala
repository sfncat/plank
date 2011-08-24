//  
//  Copyright (C) 2011 Robert Dyer
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 

using Gdk;
using Gee;
using Gtk;

using Plank.Factories;

namespace Plank.Items
{
	public class PlankDockItem : ApplicationDockItem
	{
		public PlankDockItem.with_dockitem (string dockitem)
		{
			base.with_dockitem (dockitem);
		}
		
		protected override ClickAnimation on_clicked (PopupButton button, ModifierType mod)
		{
			Factory.main.on_item_clicked ();
			return ClickAnimation.DARKEN;
		}
		
		public override ArrayList<MenuItem> get_menu_items ()
		{
			return get_plank_menu_items ();
		}
		
		public static ArrayList<MenuItem> get_plank_menu_items ()
		{
			var items = new ArrayList<MenuItem> ();
			
			var item = create_menu_item (_("Get _Help Online..."), "help");
			item.activate.connect (() => {
				Services.System.open_uri (Factory.main.help_url);
			});
			items.add (item);
			
			item = create_menu_item (_("_Translate This Application..."), "locale");
			item.activate.connect (() => {
				Services.System.open_uri (Factory.main.translate_url);
			});
			items.add (item);
			
			items.add (new SeparatorMenuItem ());
			
			item = new ImageMenuItem.from_stock (STOCK_ABOUT, null);
			item.activate.connect (() => Factory.main.show_about ());
			items.add (item);
			
			items.add (new SeparatorMenuItem ());
			
			item = new ImageMenuItem.from_stock (STOCK_QUIT, null);
			item.activate.connect (() => Factory.main.quit ());
			items.add (item);
			
			return items;
		}
	}
}
