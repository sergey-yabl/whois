## @file
# @brief содержит вспомогательные функции-утилиты
# реализация Util

## @package Util
# @brief общеупотребительные функции-утилиты
package Util;
# *********************************************************************

use strict;
use warnings;
use utf8;

use Carp;
use Data::Dumper;
use Encode;
use YAML::XS;
use Socket 'inet_ntoa';
use Sys::Hostname 'hostname';
use JSON;

use MIME::Base64;

use base "Exporter";

our @EXPORT_OK = qw(rand_range debug trim tstamp format_date println);

our %cache = ();  # здесь будем хранить кэшированные данные


## @method int rand_range([int rangeBegin, int rangeEnd])
# Возвращает целое случайное число.
# @param \c rangeBegin - нижняя граница диапазона случайного значения (не обязательна)
# @param \c rangeEnd    - верхняя граница диапазона случайного значения (не обязательна)
# @return сгенерированное случайное значение в указаном диапазоне
sub rand_range
# ----------------------------------------------------------
{
	my ($x, $y) = @_;
	# если указан только один параметр
	!$y ? 
		return  int(rand($x||1000+1)) :
		return  int(rand($y-$x+1)+$x);
}
# ----------------------------------------------------------



sub println
# ----------------------------------------------------------
{
	print @_, "\n";
}
# ----------------------------------------------------------



## @method string trim(string str)
# удялет концевые пробельные символы
# @return строку с удаленными концевыми пробелами
sub trim
# ---------------------------------------------------------------------
{
	my $val = shift;

	return unless defined $val;
	if (ref $val) { croak 'Trim operation is not allowed for refference object!'; return undef }

	$val =~ s/^\s+//;
	$val =~ s/\s+$//;

	return $val;
}
# ---------------------------------------------------------------------



## @method string trace(void)
# возвращает цепочку вызовов в виде строки. Если возвращаемое значение не ожидается, результат выводится на STDOUT
# @return строка цепочки вызовов
sub trace
# ---------------------------------------------------------------------
{
	my $object = $_[1];
	my $i = 1;
	my @callerResult;
	my $projectPath = base_path();
	my $result = "call trace: ".(ref $object)."\n------------------------------------------------\n";
	while (my($package, $filename, $line, $sub) = caller($i++)) {
		last unless $line;
		$filename =~ s/$projectPath//;
		$result .= ($i-1).': '.$filename.':'.$line."\n";
	}
	$result .= "------------------------------------------------\n";
	defined wantarray ? return $result : println $result;
}
# ---------------------------------------------------------------------



## @method string get_dump([hashref|arrayref|string] p)
# @param p - структура данных, дамп которой требуется получить. Может быть ссылкой на массив или хэш, либо же скаляром
# @return строку дампа переданого параметра
sub get_dump
# ---------------------------------------------------------------------
{
	my $dump = Dumper(shift);
	$dump =~ s/\n/__n__/g;
	$dump =~ s/\s{4}/ /g;
	$dump =~ s/__n__/\n/g;

	return $dump;
}
# ---------------------------------------------------------------------


### @method void debug([hashref|arrayref|string]);
## выполняет дамп переданных параметров в debug-log
## @param p - структура данных, дамп которой требуется получить. Может быть ссылкой на массив или хэш, либо же скаляром
#sub debug
## ----------------------------------------------------------
#{
#
#	my $fpath = Cwd::getcwd().'/debug.log';
#
#	# дампим переданыные параметры
#	for my $data (@_) {
#		$data = '' unless defined $data;
#		my $str = ref $data ? get_dump($data) : $data;
#		my $rand = sprintf("%.0f", rand(100000));
#
#		my $openFlag = Encode::is_utf8($str) ? '>>:utf8' : '>>:raw';
#
#		# my $openFlag = utf8::is_utf8($str) ? '>>:utf8' : '>>';
#		open(W, $openFlag, $fpath) or die("Can not open debug.log file '".$fpath."': ".$!);
#		print W "\n-- $rand -------------------- \n" if ref $data;
#		print W $str;
#		print W "\n-- $rand -------------------- " if ref $data;
#		print W "\n";
#		# раскомментировать, если надо понять где забыли убрать debug
#		# print W Util::trace;
#		close W;
#
#	}
#
#	return 1;
#
#}
## ----------------------------------------------------------


## @method void debug([hashref|arrayref|string]);
# выполняет дамп переданных параметров в debug-log
# @param p - структура данных, дамп которой требуется получить. Может быть ссылкой на массив или хэш, либо же скаляром
sub debug
# ----------------------------------------------------------
{

	my $fpath = get_log_dir().'/debug.log';

	# дампим переданыные параметры
	for my $data (@_) {
		$data = '' unless defined $data;
		my $str = ref $data ? get_dump($data) : $data;
		my $rand = sprintf("%.0f", rand(100000));

		my $openFlag = Encode::is_utf8($str) ? '>>:utf8' : '>>:raw';

		# my $openFlag = utf8::is_utf8($str) ? '>>:utf8' : '>>';
		open(W, $openFlag, $fpath) or die("Can not open debug.log file '".$fpath."': ".$!);
		print W "\n-- $rand -------------------- \n" if ref $data;
		print W $str;
		print W "\n-- $rand -------------------- " if ref $data;
		print W "\n";
		# раскомментировать, если надо понять где забыли убрать debug
		# print W Util::trace;
		close W;

	}

	return 1;

}
# ----------------------------------------------------------


## @method bool debug_trace(void)
# выводит в дебаг-лог трассировку вызовов
sub debug_trace {
	return @_ ? debug( @_, trace( 1 ) ) : debug( trace( 1 ) );
}


# time обязательно должен быть определен (now, +1d, +2M и т.д.)
# двухзначный год не поддерживается
sub format_date
# ----------------------------------------------------------
{
	my ($time, $format, $is_gmt) = @_;

	$format = 'YYYY-MM-DD' unless $format;

	my $pattern = '';
	my $letter  = '';
	my @order;
	my $countLetter = 0;

	# определяем формат sprintf
	for (split //, $format, -1) {

		if ($letter ne $_) {

			if ($countLetter) {
				$pattern .=  '%0' . $countLetter . 'd';
				$countLetter = 0;
			}

			if ($_ !~ /[YMDhms]/) {
				$pattern .= $_;
				next
			}

			$letter = $_;
			push @order, $letter; # порядок следования
		}

		++$countLetter;
	}

	$time = expire_calc($time);
	my %data;
	@data{qw/s m h D M Y/} = $is_gmt ? gmtime($time) : localtime($time);
	$data{Y}+=1900;
	$data{M}++;

	return sprintf($pattern, @data{(@order)});
}
# ----------------------------------------------------------



# int expire_calc(string $tm)
# This routine creates an expires time exactly some number of
# hours from the current time.  It incorporates modifications from Mark Fisher.
# Format for time $tm can be in any of the forms... ([timestamp][+/-offset])
# timestamp may be:
#    "now"      string -- expire immediately
#    timestamp  int    -- seconds after 1970 year
# offset may be:
#   "+1D"   -- in 1 day
#   "+3M"   -- in 3 months
#   "+2Y"   -- in 2 years
#   "+180s" -- in 180 seconds
#   "+2m"   -- in 2 minutes
#   "+12h"  -- in 12 hours
#   "-3m"   -- 3 minutes ago(!)
sub expire_calc
# ----------------------------------------------------------
{
	my $time = shift;
	my(%unitList)=('s'=>1, 'm'=>60, 'h'=>60*60, 'D'=>60*60*24, 'M'=>60*60*24*30, 'Y'=>60*60*24*365);
	return time if (!$time || lc($time) eq 'now');
	if ( $time =~ /^(now|\d+)?([+-](?:\d+|\d*\.\d*))([smhDMY]?)/ ) { return ( ( !$1 || $1 eq 'now' ) ? time : $1 )  +$2 * $unitList{$3} }
	return $time;
}
# ----------------------------------------------------------


## @method string readFile(string fpath[, hash %p])
# Считывает содержимое файла в строку. 
# @param \c fpath  - путь к файлу (абсолютный, либо относительный от корня директории FM)
#                \c вместо пути может передаваться уже открытый filehandler (удобно при использовании функции open2 из модуля IPC::Open2)
# @param \c p      - параметры, поддерживаются следующие кллючи:
#                \c utf8 - если установлено в true, данные будут возвращены с поднятым utf8-флагом
# @note Для перехвата ошибок используйте eval{}
# @return содержимое файла в виде строки;
sub read_file
# ----------------------------------------------------------
{
	my $path = shift;
	my %p = @_;

	die('Can not read data from file: path value is empty') unless $path;

	local $/ = undef;
	my $content;

	if ( ref $path eq 'GLOB' ) {
		$content = <$path>;
		return $content;
	}

	$path = Util::abs_path($path);
	unless (-e $path) { return carp ("File '$path' not found.") };

	open(F, '<' .($p{utf8} ? ':utf8' : '') , $path) or carp('Can not open file : '.$path.'. '.$!);
	$content = <F>;
	close F;

	return $content;
}
# ----------------------------------------------------------


## @method hashref read_yaml(string path)
# считывает данные из yaml-файла и возвращает структуру данных
# @arg \c path   - путь к yaml-файлу
sub read_yaml
# ----------------------------------------------------------
{
	# my $string = read_file($_[0], utf8 => 1);
	my $string = read_file($_[0]);
	return YAML::XS::Load($string);
}
# ----------------------------------------------------------


# @method string read_data()
# Считывает и возвращает данные из раздела __DATA__
# @return строку считанных данных
sub read_data
# ----------------------------------------------------------
{
	my $handler = (caller)[0].'::DATA';
	seek $handler,0,0;
	my $content = join "", <$handler>;
	return trim($content);
}
# ----------------------------------------------------------


## @method string replace_xml_tag(string xml, hashref replace)
# Выполняет замену содержимого тегов в переданом xml
# @param \c xml     - \c string XML в которой необходимо выполнить замену
# @param \c replace - \c hashref имена тегов (case-insensitive) и подставляемых в них значений в виде списка: tagName => tagValue
# @note замена выполняется для ВСЕХ найденных тегов
# @note для удаления тега необходимо использовать ключевое слово "_remove" в качестве его значения
# @return результирующий XML
sub replace_xml_tag
# ----------------------------------------------------------
{
	my ($xml, $replace) = @_;

	while ( my ($tag, $value) = each %$replace ) {
		next unless defined $value;
		if ($value eq '_remove') {
			$xml =~ s/(<$tag>)([^<>]+)(<\/$tag>)//gi;
			next;
		}
		$xml =~ s/(<$tag>)([^<>]+)(<\/$tag>)/$1$value$3/;
	}

	return $xml;
}
# ----------------------------------------------------------



# Formats date/time with passed template
# YY - 2-digit year, YYYY - 4-digit year
# MM - 2-digit (with leading zero) month, M - 2-digit (without leading zero) month
# MMM - month short name, MMMM - month long name
# DD - 2-digit (with leading zero) month day, D - 2-digit (without leading zero) month day
# DDD - weekday short name, DDDD - weekday long name
# AM - AM/PM flag
# hh - 2-digit (with leading zero) hour, h - 2-digit (without leading zero) hour
# mm - 2-digit (with leading zero) minute, m - 2-digit (without leading zero) minute
# ss - 2-digit (with leading zero) second, s - 2-digit (without leading zero) second
# 2011.07.05: Добавлена поддержка экранирования символов (возможность создания строки по типу 'y2011m04')
sub tstamp
# ----------------------------------------------------------
{
	my $format=shift @_ || "YYYY-MM-DD hh:mm:ss";
	my $datetime=shift @_ || time;
	my %strings=(
	'500' => "AM", '501' => "PM",
	'400' => "January", '401' => "February", '402' => "March", '403' => "April", '404' => "May", '405' => "June", '406' => "July", '407' => "August", '408' => "September", '409' => "October", '410' => "November", '411' => "December",
	'300' => "Jan", '301' => "Feb", '302' => "Mar", '303' => "Apr", '304' => "May", '305' => "Jun", '306' => "Jul", '307' => "Aug", '308' => "Sep", '309' => "Oct", '310' => "Nov", '311' => "Dec",
	'200' => "Sunday", '201' => "Monday", '202' => "Tuesday", '203' => "Wednesday", '204' => "Thursday", '205' => "Friday", '206' => "Saturday",
	'100' => "Sun", '101' => "Mon", '102' => "Tue", '103' => "Wed", '104' => "Thu", '105' => "Fri", '106' => "Sat"
	);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($datetime);
	$year+=1900;

	# выбираем экранированные символы
	my @r = $format =~ /\\(.)/g;
	$format =~ s/\\./\\/g;

	if ($format=~m/AM/) {
		my $ampmhour = ($hour % 12) || 12;
		$format=~s/hh/sprintf("%02u",$ampmhour)/eg;
		$format=~s/h/$ampmhour/eg;
		$format=~s/AM/($hour>11?"^501":"^500")/eg;
	} 
	else {
		$format=~s/hh/sprintf("%02u",$hour)/eg;
		$format=~s/h/$hour/eg;
	};

	$format=~s/mm/sprintf("%02u",$min)/eg;
	$format=~s/m/$min/eg;
	$format=~s/ss/sprintf("%02u",$sec)/eg;
	$format=~s/s/$sec/eg;
	
	$format=~s/YYYY/$year/eg;
	$format=~s/YY/sprintf("%02u",$year % 100)/eg;
	$format=~s/MMMM/sprintf("^4%02u",$mon)/eg;
	$format=~s/MMM/sprintf("^3%02u",$mon)/eg;
	$format=~s/MM/sprintf("%02u",$mon+1)/eg;
	$format=~s/M/($mon+1)/eg;
	$format=~s/DDDD/sprintf("^2%02u",$wday)/eg;
	$format=~s/DDD/sprintf("^1%02u",$wday)/eg;
	$format=~s/DD/sprintf("%02u",$mday)/eg;
	$format=~s/D/$mday/eg;
	$format=~s/\^(\d\d\d)/$strings{$1}/g;

	# восстанавливаем экранированные символы
	$format =~ s/\\/$_/ for @r;

	return $format;
} 
# ----------------------------------------------------------



## @method string get_log_dir(void)
# возвращает путь до директории логов без оконечного слэша
# @return string путь до директории логов
sub get_log_dir
# ----------------------------------------------------------
{
	$cache{log_dir} ||= abs_path('log');
	return $cache{log_dir};
}
# ----------------------------------------------------------


## @method string get_conf_dir(void)
# возвращает путь до директории конфигов без оконечного слэша
# @return string путь до директории конфигов
sub get_conf_dir
# ----------------------------------------------------------
{
	$cache{conf_dir} ||= abs_path('conf');
	return $cache{conf_dir};
}
# ----------------------------------------------------------



## @method string base_path()
# определяет и возвращает путь к директории проекта (без оконечного слэша)
sub base_path
# ----------------------------------------------------------
{
	unless ($cache{base_path}) {

		my ($path) = grep {-e $_.'/../lib' && -e $_.'/../conf'} @INC;
		die ('Can not define the base path in INC: '.(join "\n", @INC).'.') unless $path;

		# формируем строку абсолютного пути (без элементов "..")
		my @result;
		map { $_ eq '..' ? pop @result : push @result, $_; } ( split /\//, $path );
		pop @result;  # последний элемент - директория библиотек

		$cache{base_path} = join '/', @result;
	}

	return $cache{base_path};
}
# ----------------------------------------------------------



## @method string abs_path(string fname)
# синоним для abs_path возвращает абсолютный путь к файлу
# @param fname - путь к файлу. Может быть относительным от директории проекта или абсолютным (в этом случае просто возвращается переданное значение).
# @return абслютный путь к файлу
sub abs_path
# ----------------------------------------------------------
{
	return $_[0] =~ /^\// ? $_[0] : Util::base_path() . '/'.$_[0];
}
# ----------------------------------------------------------



## @method bool write_file(string fpath, string content)
# выполняет запись строки \c content в файл \c fpath
# @param fpath   - путь к файлу 
# @param content - контент
# @retval TRUE в случае успеха
# @retval FALSE если произошла ошибка
sub write_file
# ----------------------------------------------------------
{
	my ($fpath, $content) = @_;

	$fpath = Util::abs_path($fpath);

	# проверяем существование директории файла
	my ($fdir) = $fpath =~ m{ (.+?)/[^/]+$ }x;

	unless ($fdir) { return croak("Can not define file directory by fpath '".$fpath."'.") };
	unless (-e $fdir) { return croak("File directory ".$fdir." does not exists.") };

	my $openFlag = Encode::is_utf8($content) ? '>:utf8' : '>:raw';

	open(W, $openFlag, $fpath) or die("Can not open file for write '".$fpath."': ".$!);
	print W $content;
	close W;


	return 1;

}
# ----------------------------------------------------------


## @method string get_timestamp(void)
# возвращает строку timestamp  формата YYYY-MM-DD hh:mm:ss
# @retval \c string строка timestamp  формата YYYY-MM-DD hh:mm:ss
sub get_timestamp {
	my ($sec, $min, $hour, $d, $m, $y) = localtime();
	return sprintf('%04d-%02d-%02d %02d:%02d:%02d', 1900+$y, ++$m, $d, $hour, $min, $sec );
}


## @method string get_timestamp_hires(void)
# возвращает строку timestamp  формата YYYY-MM-DD hh:mm:ss.SSSSS
# @retval \c string строка timestamp  формата YYYY-MM-DD hh:mm:ss
sub get_timestamp_hires {
	my ($seconds, $microseconds) = Time::HiRes::gettimeofday;
	my ($sec, $min, $hour, $d, $m, $y) = localtime();
	return sprintf('%04d-%02d-%02d %02d:%02d:%02d', 1900+$y, ++$m, $d, $hour, $min, $sec );
}



## @method int is_memory_overload(int size)
# возвращает TRUE, если объем занятой памяти выполняемого скрипта превышает указанный
# @param size  -  int размер памяти в байтах
# @retval TRUE если размер памяти превысил пороговое значение
# @retval FALSE если размер памяти все еще держится в рамках приличия
sub is_memory_overload
# ----------------------------------------------------------
{
	my $memSize = shift;
	my $p = `ps up $$`;
	my $rss =  ( split /\s+/, (split /\n/, $p)[1] )[5];
	return $rss > $memSize;
}
# ----------------------------------------------------------







1;
