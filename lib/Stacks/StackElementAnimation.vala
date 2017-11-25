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
	public enum StackElementAnimationType
	{
		HOVER = 0,
		ZOOM,
	}
	
	public enum StackElementAnimationState
	{
		RUNNING = 0,
		PAUSED,
		NEEDS_DRAWBACK,
		FINISHED,
	}
	
	public abstract class StackElementAnimation : GLib.Object
	{
		public unowned StackElement Element { get; construct; }
		
		public StackElementAnimationState State { get; protected set; }
		
		public abstract StackElementAnimationType Type { get; }
		
		protected int64 trigger_time;
		protected double animation_duration;

		public StackElementAnimation (StackElement element)
		{
			GLib.Object (Element : element);
		}
		
		construct
		{
			State = StackElementAnimationState.RUNNING;
			trigger_time = GLib.get_monotonic_time ();
			animation_duration = Stack.DEFAULT_ANIMATION_LENGTH * 1000;
		}
		
		public virtual void reset ()
		{
			State = StackElementAnimationState.RUNNING;
			trigger_time = GLib.get_monotonic_time ();
		}

		public virtual void resume ()
		{
			State = StackElementAnimationState.RUNNING;
			trigger_time = GLib.get_monotonic_time ();
		}
		
		public void draw_filled_area (Cairo.Context cr)
		{
			if (State == StackElementAnimationState.FINISHED)
				return;
			
			var area = Element.Area;
			cr.rectangle (area.x, area.y, area.width, area.height);
			cr.fill ();
		}
		
		public abstract bool draw (Cairo.Context cr);
	}
}
