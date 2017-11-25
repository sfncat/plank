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
	public class StackWindow : CompositedWindow
	{
		/**
		 * The controller for this dock.
		 */
		public DockController controller { private get; construct; }
		
		
		protected Gtk.Menu menu = new Gtk.Menu ();
		
		protected Gdk.Rectangle monitor_geo;
		
		uint reposition_timer = 0;
		
		public StackWindow (DockController controller)
		{
			Object (controller: controller);
		}
		
		construct
		{
			set_accept_focus (false);
			can_focus = false;
			skip_pager_hint = true;
			skip_taskbar_hint = true;
			set_type_hint (Gdk.WindowTypeHint.DOCK);
			
			add_events (Gdk.EventMask.BUTTON_PRESS_MASK |
				Gdk.EventMask.BUTTON_RELEASE_MASK |
				Gdk.EventMask.ENTER_NOTIFY_MASK |
				Gdk.EventMask.LEAVE_NOTIFY_MASK |
				Gdk.EventMask.POINTER_MOTION_MASK |
				Gdk.EventMask.SCROLL_MASK);
			
			update_monitor_geo ();
		}
		
		public override bool button_press_event (Gdk.EventButton event)
		{
			return true;
		}
		
		public override bool button_release_event (Gdk.EventButton event)
		{
			return true;
		}
		
		public override bool enter_notify_event (Gdk.EventCrossing event)
		{
			return true;
		}
		
		public override bool leave_notify_event (Gdk.EventCrossing event)
		{
			return true;
		}
		
		public override bool motion_notify_event (Gdk.EventMotion event)
		{
			return true;
		}
		
		public override bool scroll_event (Gdk.EventScroll event)
		{
			return true;
		}
		
		public override bool draw (Cairo.Context cr)
		{
			//controller.renderer.draw_dock (cr);
			
			return true;
		}
		
		protected void update_monitor_geo ()
		{
			int x, y;
			get_position (out x, out y);
			Gdk.Screen screen = get_screen ();
			screen.get_monitor_geometry (screen.get_monitor_at_point (x, y), out monitor_geo);
		}
		
		public void set_size ()
		{
			//FIXME set_size_request (controller.position_manager.DockWidth, controller.position_manager.DockHeight);
			set_size_request (800, 480);
			reposition ();
			
			controller.renderer.reset_buffers ();
		}
		
		protected void reposition ()
		{
			if (reposition_timer != 0) {
				GLib.Source.remove (reposition_timer);
				reposition_timer = 0;
			}
			
			reposition_timer = GLib.Timeout.add (50, () => {
				reposition_timer = 0;
				
				// put it in the center of monitor
				move (monitor_geo.x + (monitor_geo.width - width_request) / 2, monitor_geo.y + (monitor_geo.height - height_request) / 2);
				
				return false;
			});
		}
	}
}
