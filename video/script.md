# PHX Departure Operations: deck script

One section per slide. This is the same text as the speaker notes in `slides\PHX_Departure_Operations.pptx`, both built by `R\43_video_script.R` from `output\tables`. Edit a copy if you rewrite by hand.

---

## Slide 1: Title

Hi, my name is Jake Moore, and I study Management Information Systems at the University of Arizona.

For this project, I wanted to understand where a late departure out of Phoenix Sky Harbor actually loses its time.

I also wanted to know what would break first if the airport got about 15% busier.

Everything I used is public data, so all of it can be checked.

---

## Slide 2: What we'll cover

I'll give you the answer early, and then walk through how I got there.

---

## Slide 3: Divider: The Problem

I'll start with the problem.

---

## Slide 4: About 1,330 takeoffs and landings a day

Sky Harbor is a very busy airport, with about 1,300 takeoffs and landings a day.

I focused on the airline departures, which come to about 190,000 flights a year.

Those flights lose about 2.7 million minutes a year waiting at the gate.

On top of that, they spend almost 1.2 million minutes waiting in line for the runway.

It's American's hub and one of Southwest's largest stations, so a slow morning here affects a lot of travelers.

That led me to two questions.

---

## Slide 5: Two questions

The first was where that time is actually being lost, whether it's the plane arriving late, the gate, or the line for the runway.

I wanted to put a dollar figure on each piece, so I could recommend one fix rather than a list.

The second was what breaks first if traffic grows by 15%.

I'll give you both answers up front.

---

## Slide 6: The answer, up front

The best fix, in my view, is thinning out the morning rush of departures, so fewer planes are trying to reach the runway at the same time.

In my base case, that's worth about $96 million a year.

That same morning line is also the first thing to break as traffic grows.

It gets about 7% worse per flight, while the rest of the delay barely moves.

Before getting into that, I want to show what the data can actually see.

---

## Slide 7: Divider: What the data can see

Next, the data.

---

## Slide 8: We start measuring at the gate

Originally, I wanted to follow a passenger from the curb all the way to takeoff.

However, nobody publishes check-in times or security wait times, and the TSA only reports how many people pass through.

So I set a rule for myself: if a step isn't measured publicly, I leave it out.

I didn't want to estimate a wait time, because one made-up number would undermine everything else.

As a result, the analysis starts when the plane lands and runs through takeoff.

---

## Slide 9: Five public sources, one table

That left me with five public sources:

- the government's on-time data for every domestic flight

- the FAA's hourly taxi times

- the FAA's official count of air traffic delays

- hourly weather at the airport

- and the TSA's hourly passenger counts

I matched each departure to its aircraft's previous arrival using the tail number, which worked for about 96% of flights.

The on-time data covers about 80% of the traffic here, since cargo and international flights aren't included.

I built everything in R, and the whole project reruns from a single script.

---

## Slide 10: Divider: Where the time goes

Now, where the time actually goes.

---

## Slide 11: 61% of gate delay starts at PHX

The first thing I wanted to know was where this delay was actually coming from.

Is Phoenix causing it, or is it inheriting late planes from other airports?

For every departure, I looked up the aircraft's previous arrival.

If that plane landed 20 minutes late, those 20 minutes came from somewhere else.

Ultimately, I expected that to be most of the delay, and it wasn't.

About 6 out of every 10 minutes of delay started here in Phoenix.

---

## Slide 12: Delay snowballs through the day

That delay also builds over the course of the day.

Early in the morning, flights leave about 5 minutes late on average.

By 8 at night, that has grown to about 20 minutes.

Each late aircraft makes its next flight late, and the effect stacks up throughout the day.

---

## Slide 13: The runway line peaks in the morning rush

The runway worked differently, because it wasn't a buildup over the day.

Rather, it started in the morning.

It peaks around 9 AM, and that's when Southwest and American both send out their first big wave of flights.

A lot of aircraft are heading to the same runway at the same time, and that adds about 10 minutes of waiting per flight.

About two-thirds of that waiting happens between 7 and 11 AM, which is why the morning is where I focused the fix.

---

## Slide 14: FAA delays are rare, and they come in bursts

I also looked at the FAA's own count of air traffic delays, which only includes holds of 15 minutes or more.

There are only about 4,300 a year, which is low for an airport this busy.

A quarter of them happen on just 10 bad days, mostly from storms and heavy traffic.

So on most days, the runway itself isn't the bottleneck.

---

## Slide 15: Storms hurt. Heat barely registers

Given that this is Phoenix, I expected heat to be a major factor.

To test it, I compared flights at the same time of day, on the same airline, in the same month.

A 110 degree hour only adds about 3 minutes of delay per flight.

Storms have a much bigger effect, at about 22 minutes per flight.

However, there aren't many storm hours, so over a full year weather is a small share of the delay.

---

## Slide 16: Gate delay created at PHX is the biggest pool

Next, I put a dollar figure on each piece.

That combines what a minute costs the airline with what a minute is worth to the passengers on board.

I used the airline industry's own cost figures and the federal government's value for travelers' time.

Delay created at the gate here is the largest, at about $314 million a year.

The runway line is next, at about $271 million.

Delay carried in on late planes is about $202 million.

These are estimates, so they could be off somewhat in either direction.

---

## Slide 17: Divider: One fix

That brings me to the fix.

---

## Slide 18: Thin the 7 to 11 AM departure bank

My recommendation is to thin out the morning rush, meaning the departures between 7 and 11 AM.

I chose it by measuring how much time could be recovered if Phoenix simply matched its own better hours.

The runway line had the most to give back.

Southwest and American each schedule about a third of that morning rush, so they would need to work it out with the FAA tower and the airport.

It's worth about $96 million a year, and even recovering a quarter of that would be about $24 million.

---

## Slide 19: It only works if the line actually shrinks

How the fix is carried out matters, though.

If departures are actually spread out, the line gets shorter, and both the airline and the passengers get that time back.

Some airports instead hold planes at the gate until the runway is clear.

That saves fuel, but passengers still leave just as late, so it's only worth about $20 million a year.

In that case, the better target would be how quickly planes turn around at the gate, where American accounts for almost 60% of the recoverable time.

---

## Slide 20: Divider: What breaks first

Now, the second question.

---

## Slide 21: The morning taxi line breaks first

To test growth, I compared the same hour on busy days and slower days, so I wasn't simply comparing mornings to evenings.

Then I increased every hour's traffic by 15%.

The runway line gets about 7% worse per flight.

Gate delay barely changes per flight, and it only grows because there are more flights.

So the morning runway line is what breaks first, and it's the same place the fix is aimed at.

---

## Slide 22: The taxi line pulls away as traffic grows

As traffic increases, the runway line keeps pulling away from everything else.

The shaded area shows the range the result could reasonably fall within.

About 92% of those busier hours are levels Phoenix has already handled, so this isn't a guess far beyond the data.

---

## Slide 23: Same answer on hot days and storm days

I also checked whether bad weather changes the result, and it doesn't.

On both hot days and storm days, the runway line still grows the most, at about 21%.

That gives me confidence the answer holds up in Phoenix's actual conditions.

---

## Slide 24: But 15% isn't coming on its own

That said, Phoenix barely grew between 2024 and 2025.

Passenger counts actually dipped slightly.

Airport traffic grew less than 1%, so reaching 15% is decades away at that pace.

Airline flights grew almost 2%, which would take roughly 8 or 9 years.

So 15% growth likely won't happen on its own.

If it does, it will probably be an airline adding a wave of morning flights, which is exactly where the line already breaks.

---

## Slide 25: Divider: So what

So, what does this mean for Phoenix?

---

## Slide 26: What PHX should watch

If I were advising the airport, I would watch three things:

- morning taxi times, since the FAA publishes them monthly and they move first

- any new morning flights, since those are the most costly

- and how quickly planes turn around at the gate, since that's the largest pool today

If I had to choose one, it would be morning taxi times.

---

## Slide 27: What this can't see

There are a few limitations I want to be upfront about:

- the analysis starts at the gate, so security lines aren't included

- about a fifth of flights aren't in the on-time data

- airlines report their own delay causes

- the TSA data is passenger counts only

- the growth test assumes the same runways and procedures

- and the dollar figures are averages, with no cost estimate for the fix itself

None of these change the direction of the answer, but they do mean the numbers carry a range.

---

## Slide 28: What I learned

The biggest lesson for me was that most of the work is getting messy public data to line up.

The modeling was the easier part.

Leaving out what I couldn't measure also made the results much more credible.

---

## Slide 29: Questions

To sum it up, if I were running Sky Harbor, I would track morning taxi times every month and work with the airlines to spread out the morning rush.

The code, the full report, and the data sources are linked below. Thank you for watching.

