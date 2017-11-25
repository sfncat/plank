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
	public class HoverStackElementAnimation : StackElementAnimation
	{
		public const int LINEWIDTH = 2;
		
		public Gdk.RGBA HoverColor { get; construct; }
		
		bool hover_out = false;

		public override StackElementAnimationType Type {
			get {
				return StackElementAnimationType.HOVER;
			}
		}
		
		public HoverStackElementAnimation (StackElement element, Gdk.RGBA color)
		{
			GLib.Object (Element : element, HoverColor : color);
		}
		
		public override void resume ()
		{
			hover_out = true;
			base.reset ();
		}

		public override void reset ()
		{
			hover_out = false;
			base.reset ();
		}
		
		public override bool draw (Cairo.Context cr)
		{
			var area = Element.Area;
			double progress = get_progress ();
			
			Theme.draw_rounded_rect (cr, area.x + LINEWIDTH, area.y + LINEWIDTH,
				area.width - 2 * LINEWIDTH, area.height - 2 * LINEWIDTH, 8, 8);
			cr.set_source_rgba (HoverColor.red, HoverColor.green, HoverColor.blue, progress * 0.20);
			cr.fill_preserve ();
			cr.set_line_width (LINEWIDTH);
			cr.set_source_rgba (HoverColor.red, HoverColor.green, HoverColor.blue, progress * 0.25);
			cr.stroke ();
			
			return true;
		}
		
		double get_progress ()
		{
			if (State == StackElementAnimationState.PAUSED)
				return 1.0;
			
			var animation_time = GLib.get_monotonic_time () - trigger_time;

			if (animation_time < animation_duration / 2) {
				var progress = easing_for_mode (AnimationMode.EASE_OUT_CUBIC, animation_time, animation_duration / 2);
				if (hover_out)
					progress = 1.0 - progress;
				return progress;
			}
			
			trigger_time = GLib.get_monotonic_time ();
			
			if (!hover_out) {
				State = StackElementAnimationState.PAUSED;
				hover_out = true;
				return 1.0;
			} else {
				State = StackElementAnimationState.FINISHED;
				return 0.0;
			}
		}
	}
}
