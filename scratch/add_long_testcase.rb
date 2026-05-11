dataset = Dataset.find(1)
long_text = "Line 1: This is a very long test case to test the scrollbar and theme styling.\n" * 100
long_text += "END OF LONG TEXT"

tc = Testcase.create!(
  dataset: dataset,
  num: dataset.testcases.maximum(:num).to_i + 1,
  group: 1,
  weight: 1
)

tc.inp_file.attach(io: StringIO.new(long_text), filename: 'input.txt', content_type: 'text/plain')
tc.ans_file.attach(io: StringIO.new(long_text.reverse), filename: 'answer.txt', content_type: 'text/plain')

puts "Added Testcase ##{tc.num} with ID #{tc.id}"
