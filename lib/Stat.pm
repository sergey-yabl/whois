## @file
# @brief класс для сбора статистики запросов к EPP

## @package Stat
# @brief класс для сбора статистики
package Stat;
# *********************************************************************

use strict;
use warnings;
use utf8;


use Accessor(
	start_time  => 'start_time',
	cur_time    => '+cur_time',
	rps_index   => '+rps_index',
	data        => 'data',
);


## @cmethod object new(hash %p)
# конструктор 
# @param p хэш параметров с ключами:
# @arg \c xxx      - \c xxx
# возвращает объект класса Stat
sub new
# ----------------------------------------------------------
{
	my ($class, %p) = @_;

	my $self = bless {
		start_time => time,
		cur_time   => time,
		rps_index  => 0,
		data       => {
			total         => 0,
			total_success => 0,
			total_error   => 0,

			check => {                # запросы check
				total   => 0,           # всего
				success => 0,           # успешных
				error   => 0,           # с ошибками
			},

			create => {               # запросы create
				total   => 0,           # всего
				success => 0,           # успешных
				error   => 0,           # с ошибками
			},

			elapsed => {              # время ответа
				min     => 1000_000_000,  # минимальное
				max     => 0,             # максимальное
				avr     => 0,             # среднее
				total   => 0,             # общая сумма
				max_rid => '',            # request-id самого медленного запроса
				rank    => {},
			},

			rps => {                   # количество запросов в секунду
				min     => 1000_000_000,  # минимальное
				max     => 0,             # максимальное
				avr     => 0,             # среднее
				total   => 0,             # общая сумма
				current => 0,             # текущая
			},

		},

	}, $class;

	return $self;
}
# ----------------------------------------------------------



## @method bool increment(string type, bool request_result, float elapsed, string rid)
# добавляет к данным статистики результаты очередного запроса
# @param \c type - \c string тип запроса check/create/info/etc
# @param \c request_result - \c bool результат выполнения запроса: 1 - успех, 0 - ошибка
sub increment {
	my ($self, $type, $is_success, $elapsed, $rid) = @_;

	# счетчик запросов
	++$self->data->{total};
	++$self->data->{ $is_success ? 'total_success' : 'total_error' };
	++$self->data->{$type}{total};
	++$self->data->{$type}{ $is_success ? 'success' : 'error' };


	# статистика по rps
	if (time == $self->cur_time) {
		++$self->data->{rps}{current};
	}
	else {
		$self->cur_time(time);
		my $rps = $self->data->{rps}{current};
		$self->data->{rps}{current} = 0;
		$self->data->{rps}{min} =  $rps if $rps < $self->data->{rps}{min};
		$self->data->{rps}{max} =  $rps if $rps > $self->data->{rps}{max};
	}

	# статистика по времени ответа
	$self->data->{elapsed}{total} += $elapsed;
	$self->data->{elapsed}{avr} = $self->data->{elapsed}{total}/$self->data->{total};

	my $rank_elapsed = $elapsed >= 1 ? int $elapsed : sprintf('%0.3f', $elapsed);
	$self->data->{elapsed}{rank}{$rank_elapsed} ||= 0;
	++$self->data->{elapsed}{rank}{$rank_elapsed};

	if ($elapsed < $self->data->{elapsed}{min}) {
		$self->data->{elapsed}{min} = $elapsed;
	}
	if ($elapsed > $self->data->{elapsed}{max}) {
		$self->data->{elapsed}{max} = $elapsed;
		$self->data->{elapsed}{max_rid} = $rid;
	}

	return 1;
}


## @method bool get_stat_line(string limit_type, int limit_value)
# отдает строку с краткой информацией по ходу выполнения
# @param \c limit_type  - \c string тип ограничения с которым был запущен скрипт: limit_number - по кол-ву запросов или limit_time - по времени тестирования
# @param \c limit_value - \c int величина установленного ограничения
# @retval \c string строка статистики
sub get_stat_line {
	my ($self, $limit_type, $limit_value) = @_;

	# mem size
	my $p = `ps up $$`;
	my $rss =  ( split /\s+/, (split /\n/, $p)[1] )[5];

	return $limit_type eq 'limit_number'
		? sprintf(
			"\r".'request: %u/%u, errors: %u, rps: %u, memory: %0.1fMB',
			$limit_value, $self->data->{total},
			$self->data->{total_error},
			int( $self->data->{total} / (time-$self->start_time) ),
			$rss/1000
		)
		: sprintf(
			"\r".'time left: %u/%u, errors: %u, rps: %u, memory: %0.1fMB',
			$limit_value, time-$self->start_time,
			$self->data->{total_error},
			int( $self->data->{total} / (time-$self->start_time) ),
			$rss/1000
		);
}



## @method string get_summary(void)
# формирует результирующую статистику в виде строки
# @return \c string статистика результатов тестирования
sub get_summary {
	my $self = shift;

	my $test_interval = $self->cur_time - $self->start_time;
	$test_interval ||= 1; # чтобы не было 0 секунд

	my $str = 
	  "Total requests: " . $self->data->{total} .' (success: '.$self->data->{total_success}.', error: '.$self->data->{total_error}.')'
	. "\n  Check requests: " . $self->data->{check}{total} .' (success: '.$self->data->{check}{success}.', error: '.$self->data->{check}{error}.')'
	. "\n  Create requests: " . $self->data->{create}{total} .' (success: '.$self->data->{create}{success}.', error: '.$self->data->{create}{error}.')'
	. "\nTotal time: ".($self->cur_time - $self->start_time) . ' sec. '
	.'(' . Util::format_date($self->start_time, 'hh:mm:ss') . ' - '. Util::format_date($self->cur_time, 'hh:mm:ss') .')'
	. "\nElapsed: "
	. "\n   max: " . $self->data->{elapsed}{max} . ' / '.$self->data->{elapsed}{max_rid}
	. "\n   min: " . $self->data->{elapsed}{min}
	. "\n   avr: " . sprintf('%0.4f', $self->data->{elapsed}{avr})
	. "\n"
	. "\nRPS: " 
	. "\n   max: " . ( $test_interval == 1 ? $self->data->{total} : $self->data->{rps}{max} )
	. "\n   min: " . ( $test_interval == 1 ? $self->data->{total} : $self->data->{rps}{min} )
	. "\n   avr: " . int ( $self->data->{total}/($test_interval) )
	;

	# 10 самых быстрых и медленных запросов
	my (@slow, @fast);
	for my $time ( sort { $a <=> $b } keys %{ $self->data->{elapsed}{rank} } ) {
		push @fast, $time .' - ' .$self->data->{elapsed}{rank}{$time}
			if scalar @fast < 10;

		unshift @slow, $time .' - ' .$self->data->{elapsed}{rank}{$time};
		pop @slow if scalar @slow > 10;
	}

	$str .= "\n\n" . sprintf('%-15s    %-15s', 'The worst', 'The best' );

	for (my $i = 0; $i < @slow; $i++) {
		$str .= "\n" . sprintf('%-15s    %-15s', $slow[$i], $fast[$i] );
	}

	return $str;
}


1;
