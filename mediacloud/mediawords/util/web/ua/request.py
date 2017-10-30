from urllib.parse import urlencode
from typing import Union

from mediawords.util.perl import decode_object_from_bytes_if_needed


class McUserAgentRequestException(Exception):
    """User agent's Request exception."""
    pass


class Request(object):
    """HTTP request object."""
    # FIXME redo properties to proper Pythonic way (with decorators).

    __slots__ = [
        '__method',
        '__url',
        '__auth_username',
        '__auth_password',
        '__headers',
        '__data',
    ]

    def __init__(self, method: str, url):
        """Constructor."""
        self.__method = None
        self.__url = None
        self.__headers = {}
        self.__data = None
        self.__auth_username = None
        self.__auth_password = None

        self.set_method(method)
        self.set_url(url)

    def __repr__(self) -> str:
        return 'Request(%(method)s, %(url)s, %(auth_username)s:%(auth_password)s, %(headers)s, %(data)s)' % {
            'method': self.__method,
            'url': self.__url,
            'auth_username': self.__auth_username,
            'auth_password': self.__auth_password,
            'headers': str(self.__headers),
            'data': self.__data,
        }

    __str__ = __repr__

    def method(self) -> str:
        """Return HTTP method, e.g. GET."""
        return self.__method

    def set_method(self, method: str) -> None:
        """Set HTTP method, e.g. GET."""
        method = decode_object_from_bytes_if_needed(method)
        if len(method) == 0:
            raise McUserAgentRequestException("Method is empty.")
        self.__method = method.upper()

    def url(self) -> str:
        """Return URL, e.g. https://www.mediacloud.org/page.html"""
        return self.__url

    def set_url(self, url: str) -> None:
        """Set URL, e.g. https://www.mediacloud.org/page.html"""
        url = decode_object_from_bytes_if_needed(url)
        if len(url) == 0:
            raise McUserAgentRequestException("URL is empty.")
        self.__url = url

    def header(self, name: str) -> Union[str, None]:
        """Return HTTP header, e.g. "utf-8' for "Accept-Encoding" parameter."""
        name = decode_object_from_bytes_if_needed(name)
        if len(name) == 0:
            raise McUserAgentRequestException("Header's name is empty.")
        name = name.lower()  # All locally stored headers will be lowercase
        if name in self.__headers:
            return self.__headers[name]
        else:
            return None

    def set_header(self, name: str, value: str) -> None:
        """Set HTTP header, e.g. "Accept-Encoding: utf-8."""
        name = decode_object_from_bytes_if_needed(name)
        value = decode_object_from_bytes_if_needed(value)
        if len(name) == 0:
            raise McUserAgentRequestException("Header's name is empty.")
        if len(value) == 0:
            raise McUserAgentRequestException("Header's value is empty.")
        name = name.lower()  # All locally stored headers will be lowercase
        self.__headers[name] = value

    def content_type(self) -> Union[str, None]:
        """Return "Content-Type" header."""
        return self.header('Content-Type')

    def set_content_type(self, content_type: str) -> None:
        """Set "Content-Type" header."""
        content_type = decode_object_from_bytes_if_needed(content_type)
        if len(content_type) == 0:
            raise McUserAgentRequestException("Content type is empty.")
        self.set_header('Content-Type', content_type)

    def content(self) -> Union[bytes, None]:
        """Get raw data sent as part of the POST request."""
        return self.__data

    def set_content(self, content: Union[bytes, dict]) -> None:
        """Set raw data sent as part of the POST request, in either raw bytes or dictionary form."""
        if isinstance(content, dict):
            content = decode_object_from_bytes_if_needed(content)
            content = urlencode(content, doseq=True)

        self.__data = content

    def set_content_utf8(self, content: Union[str, dict]) -> None:
        """Set raw data sent as part of the POST request, in either raw bytes or dictionary form; encode to UTF-8."""
        content = decode_object_from_bytes_if_needed(content)
        # FIXME
        content = decode_object_from_bytes_if_needed(content)
        self.set_content(content=content)

    def set_authorization_basic(self, username: str, password: str) -> None:
        """Set HTTP basic authorization credentials."""
        username = decode_object_from_bytes_if_needed(username)
        password = decode_object_from_bytes_if_needed(password)
        if len(username) == 0:
            raise McUserAgentRequestException("Username is empty.")
        if len(password) == 0:
            raise McUserAgentRequestException("Password is empty.")
        self.__auth_username = username
        self.__auth_password = password

    def as_string(self) -> str:
        """Return string representation of the request."""
        return str(self)