--1) В каких городах больше одного аэропорта?

--explain analyse --0.105 ms
select city, count count_airports      --получаем города, где > 1 аэропорта
from (select count(airport_code), city --в подзапросе считаем количество аэропортов по городам
from airports a
group by city) t
where t.count > 1

--2) В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

--explain analyse --7.6 ms
select distinct f.flight_id, a2.airport_name, a2.city, a.model, a.range --получаем уникальные результаты
from aircrafts a	--получаем данные по модели самолета и его максимальной дальности перелета
join flights f on a.aircraft_code = f.aircraft_code --присоединяем таблицу flights для того, чтобы связать aircrafts и airports
join airports a2 on f.departure_airport = a2.airport_code --присоединяем таблицу airports, для тогочтобы получить название аэропорта и город
where range = (select max("range") from aircrafts) -- отбираем рейсы, выполняемы самолетом, дальность перелета которого максимальна.

--3) Вывести 10 рейсов с максимальным временем задержки вылета

--explain analyse --11.3 ms
select flight_id, flight_no, departure_airport, --получаем данные по рейсам
arrival_airport, scheduled_departure, actual_departure,
actual_departure - scheduled_departure delay --в вычисляемом столбце ищем время задержки рейса
from flights f 
where actual_departure is not null --отбираем только рейсы, которые уже вылетели
order by delay desc  --сортируем по убыванию по времени задержки рейса
limit 10 --ограничиваем результат первыми 10-ю строками


--4) Были ли брони, по которым не были получены посадочные талоны?

--explain analyse --3500 ms
select b.*, bp.boarding_no --получаем данные по броням и посадочным талонам
from bookings b 
join tickets t on b.book_ref = t.book_ref --присоединяем таблицу tickets для того, чтобы связать bookings и boarding_passes
left join boarding_passes bp on t.ticket_no = bp.ticket_no --присоединям при помощи left join, для того чтобы получить null для искомых броней
where bp.boarding_no is null --ищем брони, для которых нет соответствий в таблице с посадочными талонами

/*
5) Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
	Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день.
	Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или
	более ранних рейсах в течении дня.
*/

--explain analyse --169 ms
with count_seats as (						--в cte считаем суммарное количество мест в самолете
	select count(seat_no), aircraft_code 
	from seats
	group by aircraft_code
	),
count_passengers as (						--в cte считаем количество пассажиров
	select flight_id, count(ticket_no) 
	from boarding_passes bp
	group by flight_id 
	)
select f.flight_id, f.flight_no, actual_departure, f.departure_airport,							--получаем данные по рейсам
	cs.count seats, cp.count passengers,
	cs.count - cp.count free_seats,																--считаем количество свободных мест
	(cs.count - cp.count) * 100 / cs.count percent_free_seat,
	sum(cp.count) over(partition by f.departure_airport, date_part('Day', f.actual_departure)	--считаем накопительный итог по условию задания
		order by f.actual_departure) sum_pessengers_per_day_by_airport
from flights f 
join count_seats cs on f.aircraft_code = cs.aircraft_code
join count_passengers cp on f.flight_id = cp.flight_id
where actual_departure is not null																--оставляем только рейсы, которые уже вылетели
order by f.departure_airport, f.actual_departure 												--сортируем по аэропортам и времени вылета

--6) Найдите процентное соотношение перелетов по типам самолетов от общего количества.

--explain analyse --22.8 ms
select a.model,	--получаем модель самолета
round(count(f.flight_id) * 100 / (select count(flight_id) from flights)::numeric, 2) percent_flights  --считаем процентное соотножение
from flights f
join aircrafts a on f.aircraft_code  = a.aircraft_code 
group by a.model --группируем по модели самолета

--7)Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

--explain analyse --6219 ms
with economy as (									--в cte находим билеты эконом класса для того, чтобы потом сравнить цены
	select tf.flight_id, fare_conditions, amount
	from ticket_flights tf
	where fare_conditions = 'Economy'
	),
business as (										--в cte находим билеты бизнес класса для того, чтобы потом сравнить цены
	select tf.flight_id, fare_conditions, amount
	from ticket_flights tf 
	where fare_conditions = 'Business'
	)
select f.flight_no, f.scheduled_departure, f.arrival_airport, --получаем данные по рейсам
economy.amount, economy.fare_conditions, business.amount, business.fare_conditions, a.city 
from economy
join business on economy.flight_id = business.flight_id --объединяем 2 cte
join flights f on economy.flight_id = f.flight_id   --присоединяем таблицу flights для того, чтобы получить данные по перелетам
join airports a on f.arrival_airport = a.airport_code --присоединяем таблицу airports для того, чтобы получить названия городов
where economy.flight_id = business.flight_id and economy.amount > business.amount  --сравниваем цены в рамках одного перелета

--8) Между какими городами нет прямых рейсов?

create materialized view cityes as					--создаем материализованное представление потому, что так надо))
--explain analyse --275 ms
with air as(										
	select a.airport_code z, a2.airport_code x 
	from airports a, airports a2 					--получаем декартово произведение со всеми возможными парами аэропортов
	where a.city != a2.city							--исключаем аэропорты, находящиеся в одном городе
	except 											--убираем из декартого произведения рейсы из таблицы flight
	select f.departure_airport, f.arrival_airport 
	from flights f
	)
select a.city city_1, a2.city city_2				--получаем искомые пары городов
from air
join airports a on air.z = a.airport_code			--присоединяем таблицу airports, чтобы по коду аэропорта получить его название
join airports a2 on air.x = a2.airport_code

select *											--получаем данные, полученные в материализованном представлении
from cityes c 

/*
9) Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью
 перелетов  в самолетах, обслуживающих эти рейсы
*/
--explain analyse --16.5 ms
 with distance as (												
select 6371 * acos(sind(a.latitude)*sind(b.latitude) +				--в cte считаем расстояние между всеми парами аэропортов
cosd(a.latitude)*cosd(b.latitude)*cosd(a.longitude - b.longitude)) distance,
a.city, b.city, a.airport_code ac, b.airport_code ac1				--получаем дополнительную информацию по аэропортам
from airports a, airports b											--при помощи декартова произведения получаем все возможные пары городов
where a.city != b.city)												--убираем пары с одним и тем же городом
select f.departure_airport, f.arrival_airport, a.range, d.distance,		--получаем информацию по перелетам
	case 																			--проверяем, долетит ли самолет
		when a.range >= d.distance then (select 'Самолет долетит')
		else (select 'Мы все умрем!!!')
	end to_be_or_not_to_be
from distance d
join (select distinct departure_airport, arrival_airport, aircraft_code from flights) f		--соединяем cte с реальными маршрутами
on f.departure_airport = d.ac and f.arrival_airport = d.ac1
join aircrafts a on f.aircraft_code = a.aircraft_code	--присоединяем таблицу с максимальной дальностью перелета конкретных моделей самолетов

