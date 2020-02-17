import React from "react";

export default function AudioBench() {
  return (
    <table>
      <tr>
        <th>Square 1</th>
        <td>Sweep</td>
        <td>DutyLength</td>
        <td>Volume</td>
        <td>Frequency</td>
        <td>
          <button>Apply</button>
        </td>
      </tr>
      <tr>
        <th>Square 2</th>
        <td></td>
        <td>DutyLength</td>
        <td>Volume</td>
        <td>Frequency</td>
        <td>
          <button>Apply</button>
        </td>
      </tr>
      <tr>
        <th>Wave</th>
        <td>On/Off</td>
        <td>Length</td>
        <td>Volume</td>
        <td>Frequency</td>
        <td>
          <button>Apply</button>
        </td>
      </tr>
      <tr>
        <th>Wave Table</th>
      </tr>
      <tr>
        <th>Noise</th>
        <td>Length</td>
        <td>Volume</td>
        <td>Counter</td>
        <td>??</td>
        <td>
          <button>Apply</button>
        </td>
      </tr>
    </table>
  );
}
