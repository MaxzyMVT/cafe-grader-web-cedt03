require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "markdown helper should convert URLs to clickable links" do
    text = "Check out http://example.com/test for more info."
    expected = "<p>Check out <a href=\"http://example.com/test\">http://example.com/test</a> for more info.</p>\n"
    assert_equal expected, markdown(text)
  end

  test "markdown helper should handle nil safely" do
    assert_equal "", markdown(nil)
  end
end
