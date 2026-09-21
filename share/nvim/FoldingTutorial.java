// Treesitter Folding Tutorial
//
// Open this file with:
//
//   nvim share/nvim/FoldingTutorial.java
//
// Practice keys:
//
//   zM  close all folds
//   zR  open all folds
//   zc  close fold under cursor
//   zo  open fold under cursor
//   za  toggle fold under cursor
//   zC  close fold recursively
//   zO  open fold recursively
//
// How to practice:
//
// 1. Run zM
//    - The whole file should become compact.
// 2. Run zR
//    - Everything should open again.
// 3. Move cursor to "class FoldingTutorial" and press zc.
//    - The class body should close.
// 4. Press zo on the closed class.
//    - The class body should open.
// 5. Move cursor to "runPipeline" and press za.
//    - The method should toggle open/closed.
// 6. Move cursor to "processUserEvents" and press zC.
//    - The method and nested blocks should close.
// 7. Press zO there.
//    - The method and nested blocks should open.

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class FoldingTutorial {
  private final List<Event> events = new ArrayList<>();

  public static void main(String[] args) {
    FoldingTutorial tutorial = new FoldingTutorial();
    tutorial.seedEvents();
    tutorial.runPipeline();
  }

  private void seedEvents() {
    events.add(new Event("u1", "click", 0.91));
    events.add(new Event("u1", "view", 0.33));
    events.add(new Event("u2", "purchase", 0.87));
    events.add(new Event("u3", "click", 0.12));
  }

  private void runPipeline() {
    System.out.println("== Pipeline Start ==");

    Map<String, Double> userScores = processUserEvents(events);

    for (Map.Entry<String, Double> entry : userScores.entrySet()) {
      if (entry.getValue() > 0.5) {
        System.out.println("high score user: " + entry.getKey());
      } else {
        System.out.println("low score user: " + entry.getKey());
      }
    }

    System.out.println("== Pipeline End ==");
  }

  private Map<String, Double> processUserEvents(List<Event> inputEvents) {
    return inputEvents.stream()
      .filter(event -> {
        if (event.score <= 0.0) {
          return false;
        }

        if ("view".equals(event.type)) {
          return event.score > 0.2;
        }

        return true;
      })
      .collect(
        java.util.stream.Collectors.groupingBy(
          event -> event.userId,
          java.util.stream.Collectors.averagingDouble(event -> event.score)
        )
      );
  }

  private static class Event {
    private final String userId;
    private final String type;
    private final double score;

    private Event(String userId, String type, double score) {
      this.userId = userId;
      this.type = type;
      this.score = score;
    }

    @Override
    public String toString() {
      return "Event{" +
        "userId='" + userId + '\'' +
        ", type='" + type + '\'' +
        ", score=" + score +
        '}';
    }
  }
}
