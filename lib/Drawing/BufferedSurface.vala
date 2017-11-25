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
	public class Tile
	{
		public Gdk.Rectangle area;
		
		public Tile (Gdk.Rectangle _area)
		{
			area = _area;
		}
	}
	
	public class BufferedSurface : GLib.Object
	{
		const int TILE_WIDTH = 512;
		const int TILE_HEIGHT = 512;
		const int MAX_BUFFER_DEPTH = 2;
		
		public signal void changed (Gee.Set<Tile> cleared_tiles);
		
		public Cairo.Surface Model { get; construct; }
		
		public int Height { get; construct; }
		
		public int Width { get; construct; }

		Surface master;
		Gee.Set<Tile> tiles = new Gee.HashSet<Tile> ();
		Gee.Map<Tile, Surface> surfaces = new Gee.HashMap<Tile, Surface> ();

		int max_buffer_count = 9;
		
		public BufferedSurface (int width, int height, Cairo.Surface model)
		{
			Object (Width: width, Height: height, Model: new Cairo.Surface.similar (model, Cairo.Content.COLOR_ALPHA, 1, 1));
		}
		
		construct
		{
			var rows = (int) Math.ceil ((double) Height / TILE_HEIGHT);
			var cols = (int) Math.ceil ((double) Width / TILE_WIDTH);
			
			for (int row=0; row < rows; row++)
				for (int col=0; col < cols; col++) {
					Gdk.Rectangle area = { col * TILE_WIDTH, row * TILE_HEIGHT, TILE_WIDTH, TILE_HEIGHT };
					var t = new Tile (area);
					tiles.add (t);
				}
		}
		
		~BufferedSurface ()
		{
			tiles.clear ();
			surfaces.clear ();
		}
		
		public void draw (Surface source, int x, int y)
		{
			Gdk.Rectangle area = { x, y, source.Width, source.Height };
			
			foreach (var t in get_intersects (area)) {
				var destination = surfaces.@get (t);
				if (destination == null) {
					destination = new Surface.with_cairo_surface (t.area.width, t.area.height, Model);
					surfaces.@set (t, destination);
				}
				
				unowned Cairo.Context cr = destination.Context;
				cr.set_source_surface (source.Internal, x - t.area.x, y - t.area.y);
				cr.paint ();
			}
		}

		public void clear_buffer ()
		{
			Gee.Set<Tile> removed = new Gee.HashSet<Tile> ();
			
			foreach (var t in surfaces.keys)
				removed.add (t);
			surfaces.clear ();
			
			changed (removed);
		}
		
		public void clear_area (Gdk.Rectangle area)
		{
			foreach (var t in get_intersects (area)) {
				var destination = surfaces.@get (t);
				if (destination != null) {
					unowned Cairo.Context cr = destination.Context;
					cr.save ();
					cr.set_operator (Cairo.Operator.CLEAR);
					cr.rectangle (area.x - t.area.x, area.y - t.area.y, area.width, area.height);
					cr.clip ();
					cr.paint ();
					cr.restore ();
				}
			}
		}
		
		public void draw_area_to_surface (Surface surface, Gdk.Rectangle area)
		{
			foreach (var t in get_intersects (area)) {
				var source = surfaces.@get (t);
				if (source != null) {
					unowned Cairo.Context cr = surface.Context;
					cr.set_source_surface (source.Internal, t.area.x - area.x, t.area.y - area.y);
					cr.paint ();
				}
			}
			
			// TODO put this into an Idle to prevent slow-downs
			// Clean buffers from "non-visisble" tiles if we reached the cache-size-limit
			if (surfaces.size > max_buffer_count) {
				var keep = area;
				inflate (keep, TILE_WIDTH * MAX_BUFFER_DEPTH, TILE_HEIGHT * MAX_BUFFER_DEPTH);
				keep_surfaces (keep);
			}
		}

		public Surface create_slice (Gdk.Rectangle area)
		{
			var result = new Surface.with_surface (area.width, area.height, master);
			
			foreach (var t in get_intersects (area)) {
				var source = surfaces.@get (t);
				if (source != null)
					result.Context.set_source_surface (source.Internal, t.area.x - area.x, t.area.y - area.y);
			}
			
			return result;
		}
		
		void keep_surfaces (Gdk.Rectangle keep_area)
		{
			var not_intersects = get_not_intersects (keep_area);
			Gee.Set<Tile> removed = new Gee.HashSet<Tile> ();
			
			foreach (var t in not_intersects)
				if (surfaces.unset (t, null))
					removed.add (t);
			
			max_buffer_count = int.max (surfaces.size, max_buffer_count);
			
			changed (removed);
		}
		
		Gee.Set<Tile> get_intersects (Gdk.Rectangle area)
		{
			var intersects = new Gee.HashSet<Tile> ();
			
			foreach (var t in tiles)
				if (t.area.intersect (area, null))
					intersects.add (t);
			
			return intersects;
		}
		
		Gee.Set<Tile> get_not_intersects (Gdk.Rectangle area)
		{
			var not_intersects = new Gee.HashSet<Tile> ();
			
			foreach (var t in tiles)
				if (!t.area.intersect (area, null))
					not_intersects.add (t);
			
			return not_intersects;
		}
		
		bool contains_point (Gdk.Rectangle rect, Gdk.Point point)
		{
			return ((point.x >= rect.x) && (point.x <= rect.x + rect.width) && 
				(point.y >= rect.y) && (point.y <= rect.y + rect.height));
		}
		
		void inflate (Gdk.Rectangle rect, int width, int height)
		{
			rect.x -= width;
			rect.y -= height;
			rect.width += 2 * width;
			rect.height += 2 * height;
		}
	}
}
