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
	public abstract class Stack : Gtk.EventBox, Gtk.Orientable
	{
		/**
		 * How many frames per second (roughly) we want while animating.
		 */
		const uint FPS = 60;
		
		public const uint RELAYOUT_DELAY = 250;
		public const uint AUTOSCROLL_DELAY = 250;
		public const uint DEFAULT_ANIMATION_LENGTH = 300;
		
		public const int ROW_SPACING = 4;
		public const int COLUMN_SPACING = 4;
		public const int PADDING = 16;
		
		public const int SCROLLBAR_SIZE = 12;
		
		public int IconSize { get; private set; default = 64; }

		public static Gee.Map<string, Gdk.Pixbuf> icon_cache = new Gee.HashMap<string, Gdk.Pixbuf> ();
		
		protected CompareDataFunc? element_compare_func { get; set; default = null; }
		
		public int columns { get; construct; default = 5; }
		
		public int rows { get; construct;  default = 4; }
		
		public Gtk.Orientation orientation { get; set; default = Gtk.Orientation.VERTICAL; }
		
		StackElement? HoveredElement { get; private set; }
		StackElement? ClickedElement { get; private set; }
		
		Gee.ArrayList<StackElement> elements = new Gee.ArrayList<StackElement> ();
		Gee.ArrayList<StackElement>? queued_elements = null;
		Gee.Set<StackElement> visible_elements = new Gee.HashSet<StackElement> ();
		Gee.Set<StackElementAnimation> animations = new Gee.HashSet<StackElementAnimation> ();
		
		uint animation_timer = 0;
		uint autoscroll_timer = 0;
		
		BufferedSurface? main_buffer;
		Surface? visual_buffer;
		Cairo.Pattern? border_fade_pattern;
		
		Gdk.Rectangle visible_area;
		int visible_width = 0;
		int visible_height = 0;
		int full_height = 0;
		int full_width = 0;

		Gtk.Scrollbar scrollbar;
		Gtk.Adjustment scroll_controller;
		
		Gdk.RGBA text_color;
		
		public Stack (int visible_cols, int visible_rows, Gtk.Orientation orientation)
		{
			GLib.Object (columns : visible_cols, rows: visible_rows, orientation: orientation);
		}
		
		construct
		{
			//Gtk.Settings.get_default ().set ("gtk-application-prefer-dark-theme", true);
			
			app_paintable = true;
			//double_buffered = false;
			
			add_events (Gdk.EventMask.BUTTON_PRESS_MASK |
				Gdk.EventMask.BUTTON_RELEASE_MASK |
				Gdk.EventMask.ENTER_NOTIFY_MASK |
				Gdk.EventMask.LEAVE_NOTIFY_MASK |
				Gdk.EventMask.POINTER_MOTION_MASK |
				Gdk.EventMask.SCROLL_MASK);
			
			unowned Gtk.StyleContext context = get_style_context ();
			context.add_class (Gtk.STYLE_CLASS_VIEW);
			context.lookup_color ("text_color", out text_color);			
			
			scroll_controller = new Gtk.Adjustment (0, 0, 1, 0.01, 0.1, 0.1);
			scroll_controller.value_changed.connect (animated_draw);
			
			scrollbar = new Gtk.Scrollbar (orientation, scroll_controller);
			
			if (orientation == Gtk.Orientation.VERTICAL) {
				scrollbar.set_halign (Gtk.Align.END);
				scrollbar.set_valign (Gtk.Align.FILL);
			} else {
				scrollbar.set_halign (Gtk.Align.FILL);
				scrollbar.set_valign (Gtk.Align.END);
			}
			
			add (scrollbar);
		}

		~Stack ()
		{
			if (animation_timer > 0)
				GLib.Source.remove (animation_timer);
			if (autoscroll_timer > 0)
				GLib.Source.remove (autoscroll_timer);

			scroll_controller.value_changed.disconnect (animated_draw);
			
			reset_buffers ();
			reset_caches ();
			
			animations.clear ();
			visible_elements.clear ();
			elements.clear ();
			if (queued_elements == null)
				queued_elements.clear ();
			
			print ("stack gone\n");
		}
		
		protected void reset_caches ()
		{
			icon_cache.clear ();
		}
		
		protected void reset_buffers ()
		{
			if (main_buffer != null) {
				main_buffer.changed.disconnect (buffer_changed);
				main_buffer = null;
			}
			
			visual_buffer = null;
		}
		
		protected void add_element (StackElement new_element)
		{
			if (queued_elements == null)
				queued_elements = new Gee.ArrayList<StackElement> ();
			
			new_element.owner = this;
			queued_elements.add (new_element);
		}
		
		protected void relayout ()
		{
			// Mark elements for redraw, recalculate their position and relayout them
			foreach (var element in elements) {
				element.reset ();
				add_element (element);
			}
			
			layout ();
		}

		public void layout ()
		{
			if (queued_elements == null || queued_elements.size == 0) {
				update_dimensions (new int[0], new int[0]);
				set_elements (new Gee.ArrayList<StackElement> ());
				return;
			}
#if BENCHMARK
			var start = new DateTime.now_local ();
#endif
			if (element_compare_func != null)
				queued_elements.sort (element_compare_func);
			
			int cols, rows;
			if (orientation == Gtk.Orientation.VERTICAL) {
				cols = this.columns;
				rows = (int) Math.ceil ((double) queued_elements.size / cols);
			} else {
				rows = this.rows;
				cols = (int) Math.ceil ((double) queued_elements.size / rows);
			}
			
			var row_sizes = new int[rows];
			var col_sizes = new int[cols];
			var row_offsets = new int[rows];
			var col_offsets = new int[cols];
			
			for (var i = 0; i < cols; i++)
				col_offsets [i] = PADDING;
			for (var i = 0; i < rows; i++)
				row_offsets [i] = PADDING;
			
			var col = 0, row = 0;
			foreach (var element in queued_elements) {
				var area = element.Area;
				col_sizes [col] = (int) Math.fmax (col_sizes [col], area.width);
				row_sizes [row] = (int) Math.fmax (row_sizes [row], area.height);
				
				if (col < cols - 1)
					col_offsets [col + 1] = col_offsets [col] + COLUMN_SPACING + col_sizes [col];
				if (row < rows - 1)
					row_offsets [row + 1] = row_offsets [row] + ROW_SPACING + row_sizes [row];
				
				if (area.x != col_offsets [col] || area.y != row_offsets [row])
					element.move_to (col_offsets [col], row_offsets [row]);
				
				col++;
				if (col >= cols) {
					col = 0;
					row++;
				}
			}
			
			update_dimensions (col_sizes, row_sizes);
			set_elements (queued_elements);
			queued_elements.clear ();
			queued_elements = null;
#if BENCHMARK
			var end = new DateTime.now_local ();
			var diff = end.difference (start) / 1000.0;
			message ("layout time - %f ms", diff);
#endif
			
			animated_draw ();
		}
		
		void set_elements (Gee.ArrayList<StackElement> queued_elements)
		{
			reset_buffers ();
			
			set_hovered_element (null);
			set_clicked_element (null);
			
			animations.clear ();
			visible_elements.clear ();
			elements.clear ();
			
			elements.add_all (queued_elements);
			
			update_size_request ();
		}
		
		void update_dimensions (int[] column_sizes, int[] row_sizes)
		{
			// update full_height
			if (row_sizes.length == 0) {
				full_height = 2 * PADDING;
			} else {
				int sum = 0;
				foreach (int i in row_sizes)
					sum += i;
				full_height = sum + (row_sizes.length - 1) * ROW_SPACING + 2 * PADDING;
			}

			// update full_width
			if (column_sizes.length == 0) {
				full_width = 2 * PADDING;
			} else {
				int sum = 0;
				foreach (int i in column_sizes)
					sum += i;
				full_width = sum + (column_sizes.length - 1) * COLUMN_SPACING + 2 * PADDING;
			}
			
			// update visible_width
			if (columns > 0) {
				int sum = 0;
				for (int i = 0; i < column_sizes.length && i < columns; i++)
					sum += column_sizes[i];
				//visible_width = sum + COLUMN_SPACING * (columns - 1) + 2 * PADDING;
				visible_width = int.max (sum + COLUMN_SPACING * (columns - 1) + 2 * PADDING,
					StackElement.DEFAULT_WIDTH * columns + COLUMN_SPACING * (columns - 1) + 2 * PADDING);
			} else {
				visible_width = full_width;
			}
		
			// update visible_height
			if (rows > 0) {
				visible_height = StackElement.DEFAULT_HEIGHT * rows + ROW_SPACING * (rows - 1) + 2 * PADDING;
			} else {
				visible_height = full_height;
			}
		}
		
		void update_size_request ()
		{
			if (columns <= 0)
				set_size_request (visible_width, full_height);
			else if (rows <= 0)
				set_size_request (full_width, visible_height);
			else
				set_size_request (visible_width, visible_height);
			
			if (orientation == Gtk.Orientation.VERTICAL) {
				scroll_controller.configure (scroll_controller.@value, 0, 1,
					(double) StackElement.DEFAULT_HEIGHT / full_height,
					(double) visible_height / full_height,
					(double) visible_height / full_height);
			} else {
				scroll_controller.configure (scroll_controller.@value, 0, 1,
					(double) StackElement.DEFAULT_WIDTH / full_width,
					(double) visible_width / full_width,
					(double) visible_width / full_width);
			}
			
			if (scroll_controller.@value != 0)
				scroll_controller.@value = 0;
			else
				scroll_controller.value_changed ();
			
			visible_area = {};
		}

		void do_autoscroll_to (StackElement? element)
		{
			if (autoscroll_timer > 0) {
				GLib.Source.remove (autoscroll_timer);
				autoscroll_timer = 0;
			}
			
			if (element == null)
				return;

			var area = element.Area;

			if (contains_rectangle (visible_area, area))
				return;
			
			autoscroll_timer = GLib.Timeout.add (AUTOSCROLL_DELAY, () => {
				if (!contains_xy (visible_area, area.x, area.y))
					scroll_controller.@value = (double) area.y / full_height - scroll_controller.page_size * 0.01;
				else if (!contains_xy (visible_area, area.x, area.y + area.height))
					scroll_controller.@value = (double) (area.y + area.height) / full_height - scroll_controller.page_size * 0.99;
				
				autoscroll_timer = 0;
				return false;
			});
		}
		
		void update_element_animate (StackElement? new_element, StackElement? old_element, StackElementAnimationType type)
		{
			bool new_animation_needed = true;
			foreach (var a in animations)
				if (a.Type == type) {
					if (old_element != null && a.Element == old_element) {
						a.resume ();
					} else if (new_element != null && a.Element == new_element) {
						new_animation_needed = false;
						a.reset ();
					}
				}

			if (new_animation_needed && new_element != null)
				switch (type) {
				case StackElementAnimationType.HOVER:
					animations.add (new HoverStackElementAnimation (new_element, text_color));
					break;
				case StackElementAnimationType.ZOOM:
					animations.add (new ZoomStackElementAnimation (new_element, -0.02));
					break;
				}
		
			animated_draw ();
		}
		
		protected virtual bool animation_needed (int64 render_time)
		{
			lock (animations) {
				Gee.Set<StackElementAnimation> remove = new Gee.HashSet<StackElementAnimation> ();
				foreach (var a in animations)
					if (a.State == StackElementAnimationState.FINISHED)
						remove.add (a);
				animations.remove_all (remove);
			}
			
			foreach (var a in animations)
				if (a.State == StackElementAnimationState.RUNNING
					|| a.State == StackElementAnimationState.NEEDS_DRAWBACK)
					return true;
			
			return false;
		}
		
		protected void animated_draw ()
		{
			if (animation_timer > 0)
				return;
			
			queue_draw ();
			
			if (animation_needed (GLib.get_monotonic_time ()))
				animation_timer = Gdk.threads_add_timeout (1000 / FPS, draw_timeout);
		}
		
		bool draw_timeout ()
		{
			queue_draw ();
			
			if (animation_needed (GLib.get_monotonic_time ()))
				return true;
			
			if (animation_timer > 0) {
				GLib.Source.remove (animation_timer);
				animation_timer = 0;
			}

			// one final draw to clear out the end of previous animations
			queue_draw ();
			return false;
		}
		
		void buffer_changed (Gee.Set<Tile> removed)
		{
			foreach (var t in removed)
				foreach (var e in elements)
					if (e.is_realized && t.area.intersect (e.Area, null))
						e.is_realized = false;
		}
		
		public override bool draw (Cairo.Context cr)
		{
#if BENCHMARK
			var start = new DateTime.now_local ();
#endif
			Gtk.Allocation allocation;
			get_allocation (out allocation);
			
			if (main_buffer == null) {
				main_buffer = new BufferedSurface (full_width, full_height, cr.get_target ());
				main_buffer.changed.connect (buffer_changed);
			}
			
			if (visual_buffer == null)
				visual_buffer = new Surface.with_cairo_surface (allocation.width, allocation.height, cr.get_target ());
			
			Gdk.Rectangle new_visible_area;
			Gdk.Point area_offset;
			if (orientation == Gtk.Orientation.VERTICAL) {
				new_visible_area = { allocation.x, allocation.y	+ (int)(full_height * scroll_controller.@value),
					allocation.width, allocation.height };
				area_offset = { 0, -(int)(full_height * scroll_controller.@value) };
			} else {
				new_visible_area = { allocation.x + (int)(full_width * scroll_controller.@value), allocation.y,
					allocation.width, allocation.height };
				area_offset = { -(int)(full_width * scroll_controller.@value), 0 };
			}

			if (new_visible_area != visible_area) {
				visible_area = new_visible_area;
				
				// update border pattern for masking
				border_fade_pattern = get_border_fade_pattern (allocation);
				
				// update visible elements
				visible_elements.clear ();
				foreach (var e in elements)
					if (e.Area.intersect (visible_area, null))
						visible_elements.add (e);
				
				// draw elements which are not-realized and visible in the current area
				foreach (var e in visible_elements) {
					if (e.is_realized)
						continue;
					
					var area = e.Area;
					var buffer = new Surface.with_cairo_surface (area.width, area.height, main_buffer.Model);
					e.draw (buffer.Context);
					e.is_realized = true;
					main_buffer.draw (buffer, area.x, area.y);
				}
				
				// get surface from buffer for new area
				visual_buffer.clear ();
				main_buffer.draw_area_to_surface (visual_buffer, visible_area);
			}
			
			Surface underlay_buffer, overlay_buffer;
			overlay_buffer = new Surface.with_cairo_surface (allocation.width, allocation.height, cr.get_target ());
			underlay_buffer = new Surface.with_cairo_surface (allocation.width, allocation.height, cr.get_target ());
			
			unowned Cairo.Context underlay_cr = underlay_buffer.Context;
			unowned Cairo.Context overlay_cr = overlay_buffer.Context;
			unowned Cairo.Context visual_cr = visual_buffer.Context;
			
			// draw element animations
			underlay_cr.save ();
			underlay_cr.set_operator (Cairo.Operator.ADD);
			overlay_cr.save ();
			overlay_cr.set_operator (Cairo.Operator.ADD);
			
			visual_cr.save ();
			foreach (var a in animations) {
				switch (a.State) {
				case StackElementAnimationState.FINISHED:
					break;
				case StackElementAnimationState.NEEDS_DRAWBACK:
					switch (a.Type) {
					case StackElementAnimationType.HOVER:
						break;
					case StackElementAnimationType.ZOOM:
						visual_cr.set_operator (Cairo.Operator.SOURCE);
						visual_cr.translate (area_offset.x, area_offset.y);
						a.draw (visual_cr);
						visual_cr.translate (-area_offset.x, -area_offset.y);
						break;
					}
					break;
				case StackElementAnimationState.PAUSED:
				case StackElementAnimationState.RUNNING:
				default:
					switch (a.Type) {
					case StackElementAnimationType.HOVER:
						underlay_cr.translate (area_offset.x, area_offset.y);
						a.draw (underlay_cr);
						underlay_cr.translate (-area_offset.x, -area_offset.y);
						break;
					case StackElementAnimationType.ZOOM:
						visual_cr.set_operator (Cairo.Operator.CLEAR);
						visual_cr.translate (area_offset.x, area_offset.y);
						a.draw_filled_area (visual_cr);
						visual_cr.translate (-area_offset.x, -area_offset.y);
						overlay_cr.translate (area_offset.x, area_offset.y);
						a.draw (overlay_cr);
						overlay_cr.translate (-area_offset.x, -area_offset.y);
						break;
					}
					break;
				}
			}
			
			underlay_cr.restore ();
			overlay_cr.restore ();
			visual_cr.restore ();
			
			if (border_fade_pattern != null) {
				cr.set_source_surface (underlay_buffer.Internal, allocation.x, allocation.y);
				cr.mask (border_fade_pattern);
				cr.set_source_surface (visual_buffer.Internal, allocation.x, allocation.y);
				cr.mask (border_fade_pattern);
				cr.set_source_surface (overlay_buffer.Internal, allocation.x, allocation.y);
				cr.mask (border_fade_pattern);
			} else {
				cr.set_source_surface (underlay_buffer.Internal, allocation.x, allocation.y);
				cr.paint ();
				cr.set_source_surface (visual_buffer.Internal, allocation.x, allocation.y);
				cr.paint ();
				cr.set_source_surface (overlay_buffer.Internal, allocation.x, allocation.y);
				cr.paint ();
			}
			
			// Draw scrollbar
			if (full_height > visual_buffer.Height) {
				scrollbar.get_allocation (out allocation);
				cr.translate (allocation.x, allocation.y);
				scrollbar.draw (cr);
			}
			
#if BENCHMARK
			var end = new DateTime.now_local ();
			var diff = end.difference (start) / 1000.0;
			if (diff > 5.0)
				message ("render time - %f ms", diff);
#endif
			
			return Gdk.EVENT_PROPAGATE;
		}
		
		Cairo.Pattern? get_border_fade_pattern (Gtk.Allocation allocation)
		{
			double size, full, stop, width, height;
			if (orientation == Gtk.Orientation.VERTICAL) {
				full = full_height;
				size = allocation.height;
				width = 0;
				height = size;
				stop = StackElement.DEFAULT_HEIGHT / 3.0 / size;
			} else {
				full = full_width;
				size = allocation.width;
				width = size;
				height = 0;
				stop = StackElement.DEFAULT_WIDTH / 3.0 / size;
			}
			
			if (size >= full)
				return null;
			
			// draw fade on top/bottom or left/right border if it is not reached
			var pattern = new Cairo.Pattern.linear (0, 0, width, height);
			
			if (scroll_controller.@value > 0.001) {
				pattern.add_color_stop_rgba (0, 0, 0, 0, 0);
				pattern.add_color_stop_rgba (stop, 0, 0, 0, 1);
			} else {
				pattern.add_color_stop_rgba (0, 0, 0, 0, 1);
			}
			
			if (scroll_controller.@value < 0.999 - height / full) {
				pattern.add_color_stop_rgba (1.0 - stop, 0, 0, 0, 1);
				pattern.add_color_stop_rgba (1, 0, 0, 0, 0);
			} else {
				pattern.add_color_stop_rgba (1, 0, 0, 0, 1);
			}
			
			return pattern;
		}
		
		StackElement? get_element_at (double widget_x, double widget_y)
		{
			if (visible_elements.size == 0)
				return null;
			
			Gdk.Point spot;
			if (orientation == Gtk.Orientation.VERTICAL)
				spot = { (int) widget_x,  (int) (widget_y + full_height * scroll_controller.@value) };
			else
				spot = { (int) (widget_x + full_width * scroll_controller.@value), (int) widget_y };
			
			if (HoveredElement != null && contains_point (HoveredElement.Area, spot))
				return HoveredElement;
			
			if (ClickedElement != null && contains_point (ClickedElement.Area, spot))
				return ClickedElement;
			
			foreach (var e in visible_elements)
				if (contains_point (e.Area, spot))
					return e;
			
			return null;
		}
		
		void set_hovered_element (StackElement? element)
		{
			if (HoveredElement == element)
				return;
			
			update_element_animate (element, HoveredElement, StackElementAnimationType.HOVER);

			HoveredElement = element;
			
			do_autoscroll_to (element);
		}
		
		void set_clicked_element (StackElement? element)
		{
			if (ClickedElement == element)
				return;
			
			update_element_animate (element, ClickedElement, StackElementAnimationType.ZOOM);

			ClickedElement = element;
		}
		
		public override bool leave_notify_event (Gdk.EventCrossing event)
		{
			set_hovered_element (null);
			set_tooltip_text ("");
			
			return Gdk.EVENT_PROPAGATE;
		}
		
		public override bool motion_notify_event (Gdk.EventMotion event)
		{
			if (visible_elements.size == 0)
				return Gdk.EVENT_STOP;
			
			set_hovered_element (get_element_at (event.x, event.y));
			
			if (HoveredElement != null)
				set_tooltip_text (HoveredElement.tooltip);
			else
				set_tooltip_text ("");
			
			return Gdk.EVENT_PROPAGATE;
		}
		
		public override bool button_press_event (Gdk.EventButton event)
		{
			if (visible_elements.size == 0)
				return Gdk.EVENT_STOP;
			
			set_hovered_element (get_element_at (event.x, event.y));
			set_clicked_element (HoveredElement);
			
			return Gdk.EVENT_STOP;
		}
		
		public override bool button_release_event (Gdk.EventButton event)
		{
			if (visible_elements.size == 0)
				return on_clicked (event, null);
			
			set_hovered_element (get_element_at (event.x, event.y));
			
			if (ClickedElement == null)
				return on_clicked (event, null);
			
			if (ClickedElement != HoveredElement) {
				set_clicked_element (null);
				return Gdk.EVENT_STOP;
			}
			
			var element = ClickedElement;
			set_clicked_element (null);
			
			return on_clicked (event, element);
		}
		
		public override bool scroll_event (Gdk.EventScroll event)
		{
			if (visible_elements.size == 0)
				return Gdk.EVENT_STOP;
			
			// Reset autoscrolling to prevent weird behaviour while scrolling near borders
			do_autoscroll_to (null);
			
			switch (event.direction) {
			case Gdk.ScrollDirection.DOWN:
			case Gdk.ScrollDirection.RIGHT:
				scroll_controller.@value += scroll_controller.step_increment;
				break;
			case Gdk.ScrollDirection.UP:
			case Gdk.ScrollDirection.LEFT:
				scroll_controller.@value -= scroll_controller.step_increment;
				break;
			}
			
			set_hovered_element (null);
			
			return Gdk.EVENT_PROPAGATE;
		}
		
		protected abstract bool on_clicked (Gdk.EventButton event, StackElement? element);
		
		static bool contains_rectangle (Gdk.Rectangle outer, Gdk.Rectangle inner)
		{
			return (contains_xy (outer, inner.x, inner.y)
				&& contains_xy (outer, inner.x + inner.width, inner.y + inner.height)
				&& contains_xy (outer, inner.x + inner.width, inner.y)
				&& contains_xy (outer, inner.x, inner.y + inner.height));
		}
		
		static bool contains_point (Gdk.Rectangle rect, Gdk.Point point)
		{
			if (rect.width <= 0 || rect.height <= 0)
				return false;
			
			return ((point.x >= rect.x) && (point.x <= rect.x + rect.width)
				&& (point.y >= rect.y) && (point.y <= rect.y + rect.height));
		}
		
		static bool contains_xy (Gdk.Rectangle rect, int x, int y)
		{
			if (rect.width <= 0 || rect.height <= 0)
				return false;
			
			return ((x >= rect.x) && (x <= rect.x + rect.width)
				&& (y >= rect.y) && (y <= rect.y + rect.height));
		}
	}
}

