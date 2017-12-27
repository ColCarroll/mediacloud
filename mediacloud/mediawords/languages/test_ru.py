from unittest import TestCase

from mediawords.languages.ru import RussianLanguage


# noinspection SpellCheckingInspection
class TestRussianLanguage(TestCase):

    def setUp(self):
        self.__tokenizer = RussianLanguage()

    def test_language_code(self):
        assert self.__tokenizer.language_code() == "ru"

    def test_stop_words_map(self):
        stop_words = self.__tokenizer.stop_words_map()
        assert "имеет" in stop_words
        assert "not_a_stopword" not in stop_words

    def test_stem(self):
        input_words = ["победу", "Имеют"]
        expected_stems = ["побед", "имеют"]
        actual_stems = self.__tokenizer.stem(input_words)
        assert expected_stems == actual_stems

    def test_split_text_to_sentences(self):
        """Simple paragraph + some non-breakable abbreviations."""
        input_text = """
            Новозеландцы пять раз признавались командой года по версии IRB и являются лидером по количеству набранных
            очков и единственным коллективом в международном регби, имеющим положительный баланс встреч со всеми своими
            соперниками. «Олл Блэкс» удерживали первую строчку в рейтинге сборных Международного совета регби дольше,
            чем все остальные команды вместе взятые. За последние сто лет новозеландцы уступали лишь шести национальным
            командам (Австралия, Англия, Родезия, Уэльс, Франция и ЮАР). Также в своём активе победу над «чёрными» имеют
            сборная Британских островов (англ.)русск. и сборная мира (англ.)русск., которые не являются официальными
            членами IRB. Более 75 % матчей сборной с 1903 года завершались победой «Олл Блэкс» — по этому показателю
            национальная команда превосходит все остальные.
        """
        expected_sentences = [
            (
                'Новозеландцы пять раз признавались командой года по версии IRB и являются лидером по количеству '
                'набранных очков и единственным коллективом в международном регби, имеющим положительный баланс встреч '
                'со всеми своими соперниками.'
            ),
            (
                '«Олл Блэкс» удерживали первую строчку в рейтинге сборных Международного совета регби дольше, чем все '
                'остальные команды вместе взятые.'
            ),
            (
                'За последние сто лет новозеландцы уступали лишь шести национальным командам (Австралия, Англия, '
                'Родезия, Уэльс, Франция и ЮАР).'
            ),
            (
                'Также в своём активе победу над «чёрными» имеют сборная Британских островов (англ.)русск. и сборная '
                'мира (англ.)русск., которые не являются официальными членами IRB.'
            ),
            (
                'Более 75 % матчей сборной с 1903 года завершались победой «Олл Блэкс» — по этому показателю '
                'национальная команда превосходит все остальные.'
            ),
        ]
        actual_sentences = self.__tokenizer.split_text_to_sentences(input_text)
        assert expected_sentences == actual_sentences

    def test_split_text_to_sentences_abbreviation(self):
        """Abbreviation ("в т. ч.")."""
        input_text = "Топоры, в т. ч. транше и шлифованные. Дания."
        expected_sentences = [
            'Топоры, в т. ч. транше и шлифованные.',
            'Дания.',
        ]
        actual_sentences = self.__tokenizer.split_text_to_sentences(input_text)
        assert expected_sentences == actual_sentences

    def test_split_text_to_sentences_abbreviation_2(self):
        """Abbreviation ("род.")."""
        input_text = """
            Влади́мир Влади́мирович Пу́тин (род. 7 октября 1952, Ленинград) — российский государственный и политический
            деятель; действующий (четвёртый) президент Российской Федерации с 7 мая 2012 года. Председатель Совета
            министров Союзного государства (с 2008 года). Второй президент Российской Федерации с 7 мая 2000 года по 7
            мая 2008 года (после отставки президента Бориса Ельцина исполнял его обязанности с 31 декабря 1999 по 7 мая
            2000 года).
        """
        expected_sentences = [
            (
                'Влади́мир Влади́мирович Пу́тин (род. 7 октября 1952, Ленинград) — российский государственный и '
                'политический деятель; действующий (четвёртый) президент Российской Федерации с 7 мая 2012 года.'
            ),
            'Председатель Совета министров Союзного государства (с 2008 года).',
            (
                'Второй президент Российской Федерации с 7 мая 2000 года по 7 мая 2008 года (после отставки президента '
                'Бориса Ельцина исполнял его обязанности с 31 декабря 1999 по 7 мая 2000 года).'
            ),
        ]
        actual_sentences = self.__tokenizer.split_text_to_sentences(input_text)
        assert expected_sentences == actual_sentences

    def test_split_text_to_sentences_name_abbreviations(self):
        """Name abbreviations."""
        input_text = """
            Впоследствии многие из тех, кто вместе с В. Путиным работал в мэрии Санкт-Петербурга (И. И. Сечин, Д. А.
            Медведев, В. А. Зубков, А. Л. Кудрин, А. Б. Миллер, Г. О. Греф, Д. Н. Козак, В. П. Иванов, С. Е. Нарышкин,
            В. Л. Мутко и др.) в 2000-е годы заняли ответственные посты в правительстве России, администрации президента
            России и руководстве госкомпаний.
        """
        expected_sentences = [
            (
                'Впоследствии многие из тех, кто вместе с В. Путиным работал в мэрии Санкт-Петербурга (И. И. Сечин, Д. '
                'А. Медведев, В. А. Зубков, А. Л. Кудрин, А. Б. Миллер, Г. О. Греф, Д. Н. Козак, В. П. Иванов, С. Е. '
                'Нарышкин, В. Л. Мутко и др.) в 2000-е годы заняли ответственные посты в правительстве России, '
                'администрации президента России и руководстве госкомпаний.'
            ),
        ]
        actual_sentences = self.__tokenizer.split_text_to_sentences(input_text)
        assert expected_sentences == actual_sentences

    def test_split_text_to_sentences_name_date(self):
        """Date ("19.04.1953")."""
        input_text = """
            Род Моргенстейн (англ. Rod Morgenstein, род. 19.04.1953, Нью-Йорк) — американский барабанщик, педагог. Он
            известен по работе с хеви-метал группой конца 80-х Winger и джаз-фьюжн группой Dixie Dregs. Участвовал в
            сессионной работе с группами Fiona, Platypus и The Jelly Jam. В настоящее время он профессор музыкального
            колледжа Беркли, преподаёт ударные инструменты.
        """
        expected_sentences = [
            'Род Моргенстейн (англ. Rod Morgenstein, род. 19.04.1953, Нью-Йорк) — американский барабанщик, педагог.',
            'Он известен по работе с хеви-метал группой конца 80-х Winger и джаз-фьюжн группой Dixie Dregs.',
            'Участвовал в сессионной работе с группами Fiona, Platypus и The Jelly Jam.',
            'В настоящее время он профессор музыкального колледжа Беркли, преподаёт ударные инструменты.',
        ]
        actual_sentences = self.__tokenizer.split_text_to_sentences(input_text)
        assert expected_sentences == actual_sentences

    def test_split_sentence_to_words(self):
        input_sentence = (
            'Род Моргенстейн (англ. Rod Morgenstein, род. 19.04.1953, Нью-Йорк) — американский барабанщик, педагог. Он '
            'известен по работе с хеви-метал группой конца 80-х Winger и джаз-фьюжн группой Dixie Dregs.'
        )
        expected_words = [
            'род', 'моргенстейн', 'англ', 'rod', 'morgenstein', 'род', '19.04', '1953', 'нью-йорк', 'американский',
            'барабанщик', 'педагог', 'он', 'известен', 'по', 'работе', 'с', 'хеви-метал', 'группой', 'конца', '80', 'х',
            'winger', 'и', 'джаз-фьюжн', 'группой', 'dixie', 'dregs',
        ]
        actual_words = self.__tokenizer.split_sentence_to_words(input_sentence)
        assert expected_words == actual_words
