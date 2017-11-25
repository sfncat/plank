//
//  Copyright (C) 2011 Rico Tzschichholz
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
	public class ZoomStackElementAnimation : StackElementAnimation
	{
		public double ZoomAmount { get; construct; }
		
		bool zoom_out = false;

		public override StackElementAnimationType Type {
			get {
				return StackElementAnimationType.ZOOM;
			}
		}
		
		public ZoomStackElementAnimation (StackElement element, double zoom_amount)
		{
			GLib.Object (Element : element, ZoomAmount : zoom_amount);
		}
		
		public override void resume ()
		{
			zoom_out = true;
			base.reset ();
		}

		public override void reset ()
		{
			zoom_out = false;
			base.reset ();
		}
		
		public override bool draw (Cairo.Context cr)
		{
			if (State == StackElementAnimationState.FINISHED)
				return true;
			
			var area = Element.Area;
			var source = new Surface.with_cairo_surface (area.width, area.height, cr.get_target ());
			unowned Cairo.Context source_cr = source.Context;

			if (State == StackElementAnimationState.NEEDS_DRAWBACK) {
				Element.draw (source_cr);
				cr.set_source_surface (source.Internal, area.x, area.y);
				State = StackElementAnimationState.FINISHED;
				return true;
			}

			double progress = get_progress ();

			var target = new Surface.with_cairo_surface (area.width, area.height, cr.get_target ());
			var pattern = new Cairo.Pattern.for_surface (source.Internal);
			Cairo.Matrix current_matrix;
			pattern.get_matrix (out current_matrix);
			current_matrix.scale (1.0 - ZoomAmount * progress, 1.0 - ZoomAmount * progress);
			pattern.set_matrix (current_matrix);
			pattern.set_filter (Cairo.Filter.BEST);
			Element.draw (source_cr);
			target.Context.set_source (pattern);
			target.Context.paint ();
			
			cr.set_source_surface (target.Internal, area.x - (area.width / 2 * ZoomAmount * progress), area.y - (area.height / 2 * ZoomAmount * progress));
			cr.paint ();
			
			//buffer.Context.mask (pattern);
			//surface.Context.set_source_surface (buffer.Internal, area.x, area.y);
			
			return true;
		}
		
		double get_progress ()
		{
			if (State == StackElementAnimationState.PAUSED)
				return 1.0;
			
			var animation_time = GLib.get_monotonic_time () - trigger_time;

			if (animation_time < animation_duration / 2) {
				var progress = easing_for_mode (AnimationMode.EASE_OUT_CUBIC, animation_time, animation_duration / 2);
				if (zoom_out)
					progress = 1.0 - progress;
				return progress;
			}
			
			trigger_time = GLib.get_monotonic_time ();
			
			if (!zoom_out) {
				State = StackElementAnimationState.PAUSED;
				zoom_out = true;
				return 1.0;
			} else {
				State = StackElementAnimationState.FINISHED;
				return 0.0;
			}
		}
	}
}
